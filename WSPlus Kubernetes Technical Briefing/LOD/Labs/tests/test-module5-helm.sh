#!/usr/bin/env bash
# Module 5 / Lab 1: Helm — install / upgrade / rollback the AKS Store Demo.
# Reuses an existing AKS (defaults to aks-${LAB_INSTANCE} in azure-rg).
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module5-helm.sh
#   LAB_INSTANCE=999001 ./test-module5-helm.sh cleanup
#
# Phases: setup install upgrade rollback template cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

WORK_DIR="${TMPDIR:-/tmp}/m5-helm-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"
CHART_DIR="$WORK_DIR/aks-store-demo/charts/aks-store-demo"

phase_setup() {
  require az kubectl git
  if ! command -v helm >/dev/null; then
    say "Installing Helm CLI"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  helm version --short
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    fail "AKS $AKS_NAME not found in $RESOURCE_GROUP"
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
  if [[ ! -d "$WORK_DIR/aks-store-demo" ]]; then
    git clone --depth 1 https://github.com/Azure-Samples/aks-store-demo.git "$WORK_DIR/aks-store-demo"
  fi
  ls "$CHART_DIR" && cat "$CHART_DIR/Chart.yaml"
}

phase_install() {
  kubectl create namespace pets --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install aks-store "$CHART_DIR" --namespace pets
  say "Waiting for store-front Service IP"
  for i in $(seq 1 60); do
    ip="$(kubectl -n pets get svc store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [[ -n "$ip" ]] && break
    sleep 5
  done
  helm list -n pets
  [[ -n "$ip" ]] && ok "Storefront: http://$ip" || warn "no LB IP yet"
}

phase_upgrade() {
  helm upgrade aks-store "$CHART_DIR" --namespace pets --reset-then-reuse-values \
    --set storeFront.replicas=3
  kubectl -n pets get deploy store-front
  helm history aks-store -n pets
}

phase_rollback() {
  helm rollback aks-store 1 -n pets
  kubectl -n pets get deploy store-front
  helm history aks-store -n pets
}

phase_template() {
  helm template aks-store "$CHART_DIR" --namespace pets --set storeFront.replicas=2 | head -50
}

phase_cleanup() {
  helm uninstall aks-store -n pets || true
  kubectl delete namespace pets --ignore-not-found
  cleanup_rg_or_cluster
}

run_phases setup install upgrade rollback template cleanup
