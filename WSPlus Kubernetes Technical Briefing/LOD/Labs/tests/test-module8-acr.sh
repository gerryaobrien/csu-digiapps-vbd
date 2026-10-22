#!/usr/bin/env bash
# Module 8 / Part 2: ACR Continuous Patching on AKS.
# NEW RG/ACR/AKS, imports vulnerable nginx:1.25, scans with Trivy, enables
# ACR Continuous Patching with --run-immediately, scans patched image,
# rolls the deployment to the patched tag.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module8-acr.sh
#   LAB_INSTANCE=999001 ./test-module8-acr.sh cleanup
#
# Phases: setup acr aks deploy scan patching scanpatched roll cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

# Per-lab unique RG so it doesn't collide with the other module RGs.
RESOURCE_GROUP="${RESOURCE_GROUP_M8:-rg-acrcp-${LAB_INSTANCE}}"
AKS_NAME="aks-acrcp-${LAB_INSTANCE}"
ACR_NAME="${ACR_NAME:-acr${LAB_INSTANCE}}"
IMAGE_VERSION="${IMAGE_VERSION:-1.25}"
WORK_DIR="${TMPDIR:-/tmp}/m8-acr-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"

phase_setup() {
  require az kubectl
  tag_subscription
  if ! command -v trivy >/dev/null; then
    say "Installing Trivy"
    curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
      | sudo sh -s -- -b /usr/local/bin
  fi
  trivy --version | head -1
  ensure_rg
  az provider register --namespace Microsoft.ContainerRegistry >/dev/null
  az provider register --namespace Microsoft.ContainerService >/dev/null
  az extension add -n acrcssc --upgrade --only-show-errors >/dev/null 2>&1 || \
    az extension update -n acrcssc --only-show-errors >/dev/null 2>&1 || true
}

phase_acr() {
  if ! az acr show -n "$ACR_NAME" >/dev/null 2>&1; then
    say "Creating ACR $ACR_NAME (Premium)"
    az acr create -g "$RESOURCE_GROUP" -n "$ACR_NAME" --sku Premium --location "$LOCATION" >/dev/null
  fi
  say "Logging Trivy into $ACR_NAME.azurecr.io"
  az acr login --name "$ACR_NAME" --expose-token --output tsv --query accessToken \
    | trivy registry login --username 00000000-0000-0000-0000-000000000000 \
      --password-stdin "$ACR_NAME.azurecr.io"
}

phase_aks() {
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    say "Creating AKS $AKS_NAME attached to $ACR_NAME (~10 min)"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
      --attach-acr "$ACR_NAME" --no-ssh-key --location "$LOCATION" \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_deploy() {
  az acr import -n "$ACR_NAME" -g "$RESOURCE_GROUP" \
    --source "mcr.microsoft.com/mirror/docker/library/nginx:$IMAGE_VERSION" \
    --image "nginx:$IMAGE_VERSION" --force
  az acr repository show-tags -n "$ACR_NAME" --repository nginx -o table
  cat >"$WORK_DIR/nginx-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: nginx-deployment}
spec:
  replicas: 1
  selector: {matchLabels: {app: nginx}}
  template:
    metadata: {labels: {app: nginx}}
    spec:
      containers:
      - name: nginx
        image: $ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION
        ports: [{containerPort: 80}]
EOF
  kubectl apply -f "$WORK_DIR/nginx-deployment.yaml"
  kubectl rollout status deployment/nginx-deployment --timeout=180s
  kubectl get pods -l app=nginx -o wide
}

phase_scan() {
  trivy image --pkg-types os --ignore-unfixed "$ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION" || true
}

phase_patching() {
  cat >"$WORK_DIR/continuouspatching.json" <<EOF
{
  "version": "v1",
  "tag-convention": "incremental",
  "repositories": [
    {"repository": "nginx", "tags": ["$IMAGE_VERSION"], "enabled": true}
  ]
}
EOF
  say "Dry-run"
  az acr supply-chain workflow create -r "$ACR_NAME" -g "$RESOURCE_GROUP" \
    --type continuouspatchv1 --config "$WORK_DIR/continuouspatching.json" \
    --schedule 1d --dry-run
  say "Creating workflow with --run-immediately"
  az acr supply-chain workflow create -r "$ACR_NAME" -g "$RESOURCE_GROUP" \
    --type continuouspatchv1 --config "$WORK_DIR/continuouspatching.json" \
    --schedule 1d --run-immediately
  say "Waiting up to 10 min for $IMAGE_VERSION-1 tag to appear"
  for i in $(seq 1 60); do
    if az acr repository show-tags -n "$ACR_NAME" --repository nginx -o tsv | grep -q "^${IMAGE_VERSION}-1$"; then
      ok "Patched tag $IMAGE_VERSION-1 published"; return
    fi
    sleep 10
  done
  warn "Patched tag not yet visible — check 'az acr task list-runs -r $ACR_NAME -n cssc-patch-image'"
}

phase_scanpatched() {
  trivy image --pkg-types os --ignore-unfixed "$ACR_NAME.azurecr.io/nginx:$IMAGE_VERSION-1" || true
}

phase_roll() {
  sed -i "s|nginx:$IMAGE_VERSION$|nginx:$IMAGE_VERSION-1|; s|nginx:$IMAGE_VERSION\\b|nginx:$IMAGE_VERSION-1|g" "$WORK_DIR/nginx-deployment.yaml"
  kubectl apply -f "$WORK_DIR/nginx-deployment.yaml"
  kubectl rollout status deployment/nginx-deployment --timeout=180s
  kubectl get pods -l app=nginx -o wide
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

run_phases setup acr aks deploy scan patching scanpatched roll cleanup
