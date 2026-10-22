#!/usr/bin/env bash
# Module 2: What is AKS? — Azure Policy + KEDA + Dapr + Azure Vote app.
# Reuses the AKS cluster from Module 1 (aks-${LAB_INSTANCE} in azure-rg).
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module2.sh                      # all phases
#   LAB_INSTANCE=999001 ./test-module2.sh policy keda          # selected
#   LAB_INSTANCE=999001 ./test-module2.sh cleanup
#
# Phases: setup policy keda dapr vote cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

phase_setup() {
  require az kubectl
  tag_subscription
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    fail "AKS $AKS_NAME not found in $RESOURCE_GROUP — run test-module1.sh first or override AKS_NAME"
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
  ok "Reusing existing AKS cluster $AKS_NAME"
}

phase_policy() {
  say "Enabling Azure Policy add-on"
  az provider register --namespace Microsoft.PolicyInsights >/dev/null
  az aks enable-addons --addons azure-policy -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null
  kubectl get pods -n kube-system -l app=azure-policy --no-headers || true
  kubectl get pods -n gatekeeper-system --no-headers || true
  az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query addonProfiles.azurepolicy
}

phase_keda() {
  say "Enabling KEDA"
  az aks update -g "$RESOURCE_GROUP" -n "$AKS_NAME" --enable-keda >/dev/null
  az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
    --query "workloadAutoScalerProfile.keda.enabled"
}

phase_dapr() {
  say "Installing k8s-extension CLI + Dapr"
  az extension add --name k8s-extension --upgrade --only-show-errors >/dev/null 2>&1 || \
    az extension update --name k8s-extension --only-show-errors >/dev/null 2>&1 || true
  az provider register --namespace Microsoft.KubernetesConfiguration >/dev/null
  if az k8s-extension show --cluster-type managedClusters --cluster-name "$AKS_NAME" \
       -g "$RESOURCE_GROUP" --name dapr >/dev/null 2>&1; then
    warn "Dapr extension already installed"
  else
    az k8s-extension create --cluster-type managedClusters --cluster-name "$AKS_NAME" \
      -g "$RESOURCE_GROUP" --name dapr --extension-type Microsoft.Dapr \
      --auto-upgrade-minor-version false --yes
  fi
  kubectl get pods -n dapr-system 2>/dev/null || true
}

phase_vote() {
  say "Deploying Azure Vote app"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/azure-vote.yaml" \
    https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/refs/heads/master/azure-vote-all-in-one-redis.yaml
  kubectl apply -f "$tmp/azure-vote.yaml"
  say "Waiting for azure-vote-front external IP (up to 5 min)"
  local ip="" i
  for i in $(seq 1 60); do
    ip="$(kubectl get svc azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [[ -n "$ip" ]] && break
    sleep 5
  done
  [[ -n "$ip" ]] && ok "Azure Vote at http://$ip" || warn "no LB IP yet — kubectl get svc azure-vote-front"
  rm -rf "$tmp"
}

phase_cleanup() {
  say "Removing Azure Vote app, Dapr extension, and add-ons"
  kubectl delete -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/refs/heads/master/azure-vote-all-in-one-redis.yaml --ignore-not-found
  az k8s-extension delete --cluster-type managedClusters --cluster-name "$AKS_NAME" \
    -g "$RESOURCE_GROUP" --name dapr --yes 2>/dev/null || true
  az aks disable-addons --addons azure-policy -g "$RESOURCE_GROUP" -n "$AKS_NAME" 2>/dev/null || true
  az aks update -g "$RESOURCE_GROUP" -n "$AKS_NAME" --disable-keda 2>/dev/null || true
  cleanup_rg_or_cluster
}

run_phases setup policy keda dapr vote cleanup
