#!/usr/bin/env bash
# Module 4 / Lab 1: Node Auto-Provisioning (NAP / Karpenter on AKS).
# Creates a NEW Cilium-overlay cluster with --node-provisioning-mode Auto,
# applies a NodePool CR with allowed SKUs, scales an inflate Deployment
# to trigger NAP node provisioning, then scales down to observe consolidation.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module4-nap.sh
#   LAB_INSTANCE=999001 ./test-module4-nap.sh cleanup
#
# Phases: preview setup nodepool inflate scaledown cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

AKS_NAME="aks-nap-${LAB_INSTANCE}"
WORK_DIR="${TMPDIR:-/tmp}/m4-nap-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"

phase_preview() {
  require az kubectl
  # NAP is GA — no preview feature flag or aks-preview extension required.
  # Just confirm the CLI is recent enough (--node-provisioning-mode needs 2.76.0+).
  local ver
  ver="$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo 0.0.0)"
  say "az CLI version: $ver (NAP requires 2.76.0+)"
}

phase_setup() {
  tag_subscription
  ensure_rg
  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists, reusing"
  else
    say "Creating NAP cluster $AKS_NAME (Cilium overlay) — ~10 min"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
      --node-vm-size Standard_D2as_v5 \
      --node-provisioning-mode Auto \
      --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium \
      --generate-ssh-keys --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_nodepool() {
  cat >"$WORK_DIR/karp.yaml" <<'EOF'
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose On-Demand NodePool"
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1s
    budgets:
      - nodes: "100%"
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      expireAfter: Never
      requirements:
        - {key: kubernetes.io/os, operator: In, values: [linux]}
        - {key: karpenter.sh/capacity-type, operator: In, values: [on-demand]}
        - {key: karpenter.azure.com/sku-name, operator: In, values: [Standard_D2s_v5, Standard_A2m_v2, Standard_D2as_v5, Standard_D2ads_v5]}
EOF
  kubectl apply -f "$WORK_DIR/karp.yaml"
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
  kubectl scale deployment inflate --replicas 5
  say "Waiting up to 4 min for NAP to provision a node"
  for i in $(seq 1 48); do
    ready="$(kubectl get pods -l app=inflate --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
    [[ "$ready" -ge 5 ]] && break
    sleep 5
  done
  kubectl get nodes
  kubectl get pods -l app=inflate -o wide
  say "Last 30 lines of Karpenter controller logs"
  kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -c controller --tail=30 2>/dev/null || true
}

phase_scaledown() {
  kubectl scale deployment inflate --replicas 0
  say "Waiting up to 3 min for consolidation"
  sleep 30
  kubectl get nodes
  kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -c controller --tail=30 2>/dev/null || true
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

run_phases preview setup nodepool inflate scaledown cleanup
