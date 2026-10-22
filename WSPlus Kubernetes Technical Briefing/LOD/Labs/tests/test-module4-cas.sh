#!/usr/bin/env bash
# Module 4 / Lab 2: Cluster Autoscaler.
# Creates a NEW cluster with --enable-cluster-autoscaler (min 1, max 5),
# scales an inflate Deployment to 15 replicas to force scale-up.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module4-cas.sh
#   LAB_INSTANCE=999001 ./test-module4-cas.sh cleanup
#
# Phases: setup inflate scaledown cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

AKS_NAME="aks-cas-${LAB_INSTANCE}"
WORK_DIR="${TMPDIR:-/tmp}/m4-cas-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"

phase_setup() {
  require az kubectl
  tag_subscription
  ensure_rg
  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists, reusing"
  else
    say "Creating CAS cluster $AKS_NAME — ~10 min"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
      --node-count 1 --node-vm-size Standard_D2ads_v5 \
      --load-balancer-sku standard \
      --enable-cluster-autoscaler --min-count 1 --max-count 5 \
      --cluster-autoscaler-profile scan-interval=30s \
      --generate-ssh-keys --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_inflate() {
  cat >"$WORK_DIR/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: inflate}
spec:
  replicas: 0
  selector: {matchLabels: {app: inflate}}
  template:
    metadata: {labels: {app: inflate}}
    spec:
      terminationGracePeriodSeconds: 0
      containers:
      - name: inflate
        image: mcr.microsoft.com/oss/kubernetes/pause:3.10
        resources: {requests: {cpu: 1}}
EOF
  kubectl apply -f "$WORK_DIR/deploy.yaml"
  kubectl scale deployment inflate --replicas 15
  say "Waiting 3 min for autoscaler to react"
  sleep 180
  kubectl get nodes
  kubectl get pods -o wide
}

phase_scaledown() {
  kubectl delete deployment inflate
  warn "Cluster autoscaler waits ~10 min before evicting empty nodes — recheck later"
  kubectl get nodes
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

run_phases setup inflate scaledown cleanup
