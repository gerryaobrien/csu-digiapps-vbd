#!/usr/bin/env bash
# Module 8 / Part 1: Azure Key Vault + Secrets Store CSI Driver on AKS.
# Reuses an existing AKS, enables the KV addon, creates a Key Vault + secret,
# wires up role assignments, and mounts the secret into a Pod via SPC.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module8-kv.sh
#   LAB_INSTANCE=999001 ./test-module8-kv.sh cleanup
#
# Phases: setup vault rbac sync pod k8ssecret cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

ASSETS="$SCRIPT_DIR/../assets/Module8"
KV_NAME="${KV_NAME:-kv-${LAB_INSTANCE}}"
WORK_DIR="${TMPDIR:-/tmp}/m8-kv-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"

phase_setup() {
  require az kubectl
  tag_subscription
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    fail "AKS $AKS_NAME not found in $RESOURCE_GROUP"
  fi
  say "Enabling azure-keyvault-secrets-provider addon"
  az aks addon enable --addon azure-keyvault-secrets-provider \
    -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1 || warn "addon may already be enabled"
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  az aks addon list -g "$RESOURCE_GROUP" -n "$AKS_NAME" -o table
}

phase_vault() {
  if ! az keyvault show -n "$KV_NAME" >/dev/null 2>&1; then
    say "Creating Key Vault $KV_NAME (RBAC mode)"
    az keyvault create -g "$RESOURCE_GROUP" -n "$KV_NAME" --enable-rbac-authorization >/dev/null
  fi
  KV_ID="$(az keyvault show -n "$KV_NAME" --query id -o tsv)"
  CURRENT_USER_ID="$(az ad signed-in-user show --query id -o tsv)"
  say "Granting current user Key Vault Secrets Officer"
  az role assignment create --role "Key Vault Secrets Officer" \
    --assignee-object-id "$CURRENT_USER_ID" --assignee-principal-type User \
    --scope "$KV_ID" >/dev/null 2>&1 || true
  say "Sleeping 30s for role propagation"
  sleep 30
  az keyvault secret set --vault-name "$KV_NAME" --name SampleSecret \
    --value "Highly sensitive information: <place data here>" >/dev/null
  az keyvault secret list --vault-name "$KV_NAME" -o table
}

phase_rbac() {
  KV_ID="$(az keyvault show -n "$KV_NAME" --query id -o tsv)"
  KV_IDENTITY="$(az identity list --query "[? contains(name,'azurekeyvaultsecretsprovider')].principalId" -o tsv | head -1)"
  KV_CLIENT_ID="$(az identity list --query "[? contains(name,'azurekeyvaultsecretsprovider')].clientId" -o tsv | head -1)"
  [[ -z "$KV_IDENTITY" ]] && fail "azurekeyvaultsecretsprovider managed identity not found"
  echo "$KV_CLIENT_ID" > "$WORK_DIR/client_id"
  say "Granting AKS KV addon identity Key Vault Secrets User"
  az role assignment create --role "Key Vault Secrets User" \
    --assignee-object-id "$KV_IDENTITY" --assignee-principal-type ServicePrincipal \
    --scope "$KV_ID" >/dev/null 2>&1 || true
  sleep 30
}

phase_sync() {
  local tenant client
  tenant="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query identity.tenantId -o tsv)"
  client="$(cat "$WORK_DIR/client_id")"
  cp "$ASSETS/spc.yaml" "$WORK_DIR/spc.yaml"
  sed -i "s|<client-id>|$client|; s|<key-vault-name>|$KV_NAME|; s|<tenant-id>|$tenant|" "$WORK_DIR/spc.yaml"
  kubectl apply -f "$WORK_DIR/spc.yaml"
}

phase_pod() {
  kubectl apply -f "$ASSETS/pod-kv.yaml"
  kubectl wait --for=condition=Ready pod/pod-kv --timeout=180s
  say "Reading mounted secret"
  kubectl exec pod-kv -- cat /mnt/secrets-store/SampleSecret; echo
}

phase_k8ssecret() {
  say "Adding secretObjects to spc to sync as a K8s Secret"
  cat >"$WORK_DIR/spc-with-secret.yaml" <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata: {name: azure-kv-secret}
spec:
  provider: azure
  secretObjects:
  - secretName: k8s-secret
    type: Opaque
    data:
    - {key: MySecret, objectName: SampleSecret}
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: $(cat "$WORK_DIR/client_id")
    keyvaultName: $KV_NAME
    cloudName: ""
    objects: |
      array:
        - |
          objectName: SampleSecret
          objectType: secret
          objectVersion: ""
    tenantId: $(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query identity.tenantId -o tsv)
EOF
  kubectl apply -f "$WORK_DIR/spc-with-secret.yaml"
  cat >"$WORK_DIR/pod-kv-env.yaml" <<'EOF'
kind: Pod
apiVersion: v1
metadata: {name: pod-kv}
spec:
  containers:
  - name: busybox
    image: registry.k8s.io/e2e-test-images/busybox:1.29-1
    command: ["/bin/sleep", "10000"]
    volumeMounts:
    - {name: secrets-store01, mountPath: /mnt/secrets-store, readOnly: true}
    env:
    - name: SECRET_VALUE
      valueFrom: {secretKeyRef: {name: k8s-secret, key: MySecret}}
  volumes:
  - name: secrets-store01
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes: {secretProviderClass: azure-kv-secret}
EOF
  kubectl delete pod pod-kv --ignore-not-found
  kubectl apply -f "$WORK_DIR/pod-kv-env.yaml"
  kubectl wait --for=condition=Ready pod/pod-kv --timeout=180s
  kubectl exec pod-kv -- printenv | grep SECRET_VALUE
  kubectl get secret k8s-secret
  kubectl delete pod pod-kv
  sleep 5
  kubectl get secret k8s-secret 2>&1 | tail -3
}

phase_cleanup() {
  kubectl delete pod pod-kv --ignore-not-found
  kubectl delete secretproviderclass azure-kv-secret --ignore-not-found
  az keyvault delete -n "$KV_NAME" -g "$RESOURCE_GROUP" 2>/dev/null || true
  cleanup_rg_or_cluster
}

run_phases setup vault rbac sync pod k8ssecret cleanup
