#!/usr/bin/env bash
# Module 5 / Lab 2: GitOps with Flux v2 (microsoft.flux extension).
# Reuses an existing AKS, installs Flux, applies a config that reconciles
# the gitops-flux2-kustomize-helm-mt sample, demonstrates drift correction.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module5-flux.sh
#   LAB_INSTANCE=999001 ./test-module5-flux.sh cleanup
#
# Phases: setup config inspect verify drift cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

FLUX_CONFIG_NAME="cluster-config"
FLUX_NAMESPACE="cluster-config"
GIT_REPO_URL="https://github.com/Azure/gitops-flux2-kustomize-helm-mt"

phase_setup() {
  require az kubectl
  tag_subscription
  for ns in Microsoft.Kubernetes Microsoft.ContainerService Microsoft.KubernetesConfiguration; do
    az provider register --namespace "$ns" >/dev/null 2>&1 || true
  done
  for ext in k8s-configuration k8s-extension; do
    az extension add -n "$ext" --upgrade --only-show-errors >/dev/null 2>&1 || \
      az extension update -n "$ext" --only-show-errors >/dev/null 2>&1 || true
  done
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    fail "AKS $AKS_NAME not found"
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_config() {
  say "Creating Flux configuration $FLUX_CONFIG_NAME (auto-installs microsoft.flux extension)"
  az k8s-configuration flux create \
    --resource-group "$RESOURCE_GROUP" --cluster-name "$AKS_NAME" --cluster-type managedClusters \
    --name "$FLUX_CONFIG_NAME" --namespace "$FLUX_NAMESPACE" --scope cluster \
    --url "$GIT_REPO_URL" --branch main \
    --kustomization name=infra path=./infrastructure prune=true \
    --kustomization name=apps  path=./apps/staging  prune=true dependsOn=["infra"]
}

phase_inspect() {
  az k8s-configuration flux show -g "$RESOURCE_GROUP" -c "$AKS_NAME" -t managedClusters -n "$FLUX_CONFIG_NAME"
  kubectl get namespaces
  kubectl get pods -n flux-system
  kubectl get fluxconfigs,gitrepositories,kustomizations,helmreleases -A
}

phase_verify() {
  say "Waiting up to 5 min for podinfo namespace + workload"
  for i in $(seq 1 60); do
    kubectl get ns podinfo >/dev/null 2>&1 && break
    sleep 5
  done
  kubectl get all -n podinfo || true
  if kubectl -n podinfo get svc podinfo >/dev/null 2>&1; then
    kubectl -n podinfo port-forward svc/podinfo 9898:9898 >/dev/null 2>&1 &
    local pid=$!; sleep 3
    curl -s --max-time 5 http://localhost:9898 | head -10 || true
    kill "$pid" 2>/dev/null || true
  fi
}

phase_drift() {
  say "Manually scaling podinfo to 5 replicas (drift)"
  kubectl -n podinfo scale deployment podinfo --replicas=5 || true
  kubectl -n podinfo get deploy podinfo
  say "Forcing Flux reconcile"
  kubectl annotate kustomization apps -n "$FLUX_NAMESPACE" \
    reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite || true
  sleep 30
  kubectl -n podinfo get deploy podinfo
}

phase_cleanup() {
  az k8s-configuration flux delete -g "$RESOURCE_GROUP" -c "$AKS_NAME" \
    -t managedClusters -n "$FLUX_CONFIG_NAME" --yes 2>/dev/null || true
  az k8s-extension delete -g "$RESOURCE_GROUP" -c "$AKS_NAME" \
    -t managedClusters -n flux --yes 2>/dev/null || true
  cleanup_rg_or_cluster
}

run_phases setup config inspect verify drift cleanup
