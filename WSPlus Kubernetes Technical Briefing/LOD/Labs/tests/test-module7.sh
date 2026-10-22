#!/usr/bin/env bash
# Module 7: Monitoring — Azure Managed Prometheus + Azure Managed Grafana.
# Creates Azure Monitor Workspace, Managed Grafana, and a NEW AKS cluster
# wired to both. Imports kube-apiserver / etcd dashboards. Customizes metric
# ingestion (apiserver_longrunning_requests). Deploys reference app + PodMonitor.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module7.sh
#   LAB_INSTANCE=999001 ./test-module7.sh cleanup
#
# Phases: preview setup amw grafana cluster dashboards customize podmonitor cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

AKS_NAME="aks-mon-${LAB_INSTANCE}"
GRAFANA_NAME="grafana-${LAB_INSTANCE}"
AZ_MONITOR_WORKSPACE_NAME="amw-${LAB_INSTANCE}"
WORK_DIR="${TMPDIR:-/tmp}/m7-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"

phase_preview() {
  require az kubectl curl
  az extension add --name aks-preview --upgrade --only-show-errors >/dev/null 2>&1 || \
    az extension update --name aks-preview --only-show-errors >/dev/null 2>&1 || true
  az feature register --namespace Microsoft.ContainerService --name AzureMonitorMetricsControlPlanePreview >/dev/null 2>&1 || true
  say "Waiting for control-plane metrics preview to be Registered"
  for i in $(seq 1 60); do
    state="$(az feature show --namespace Microsoft.ContainerService --name AzureMonitorMetricsControlPlanePreview --query properties.state -o tsv 2>/dev/null || true)"
    [[ "$state" == "Registered" ]] && break
    printf "."; sleep 10
  done
  echo
  az provider register --namespace Microsoft.ContainerService >/dev/null
}

phase_setup() {
  tag_subscription
  ensure_rg
}

phase_amw() {
  say "Creating Azure Monitor Workspace $AZ_MONITOR_WORKSPACE_NAME"
  az monitor account create -g "$RESOURCE_GROUP" -l "$LOCATION" -n "$AZ_MONITOR_WORKSPACE_NAME" >/dev/null
}

phase_grafana() {
  az extension add -n amg --upgrade --only-show-errors >/dev/null 2>&1 || true
  say "Creating Azure Managed Grafana $GRAFANA_NAME"
  az grafana create -g "$RESOURCE_GROUP" -l "$LOCATION" -n "$GRAFANA_NAME" >/dev/null
}

phase_cluster() {
  local amw_id grafana_id
  amw_id="$(az monitor account show -g "$RESOURCE_GROUP" -n "$AZ_MONITOR_WORKSPACE_NAME" --query id -o tsv)"
  grafana_id="$(az grafana show -g "$RESOURCE_GROUP" -n "$GRAFANA_NAME" --query id -o tsv)"
  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists, reusing"
  else
    say "Creating AKS $AKS_NAME with managed metrics + Grafana wiring (~10 min)"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
      --node-count 1 \
      --enable-managed-identity --enable-azure-monitor-metrics \
      --enable-cost-analysis \
      --grafana-resource-id "$grafana_id" \
      --azure-monitor-workspace-resource-id "$amw_id" \
      --tier Standard --ssh-access disabled --generate-ssh-keys \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl cluster-info; kubectl get nodes
}

phase_dashboards() {
  az grafana folder create -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --title AKS-Labs >/dev/null 2>&1 || true
  az grafana dashboard import -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --folder AKS-Labs --definition 20331
  az grafana dashboard import -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --folder AKS-Labs --definition 20330
  ok "Grafana endpoint: $(az grafana show -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --query properties.endpoint -o tsv)"
}

phase_customize() {
  kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml
  say "Patching ama-metrics-settings-configmap to keep apiserver_longrunning_requests"
  # Replace the default-targets-metrics-keep-list block: append the metric to controlplane-apiserver
  kubectl -n kube-system patch cm ama-metrics-settings-configmap --type merge -p '{
    "data": {
      "default-targets-metrics-keep-list": "controlplane-apiserver = \"apiserver_longrunning_requests\"\n"
    }
  }' || warn "patch failed — edit manually with: kubectl edit cm ama-metrics-settings-configmap -n kube-system"
}

phase_podmonitor() {
  kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/internal/referenceapp/prometheus-reference-app.yaml
  kubectl wait --for=condition=Ready pod -l app=prometheus-reference-app --timeout=300s
  kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml
  kubectl get pods,svc -l app=prometheus-reference-app
  ok "Browse Grafana > Explore > Managed_Prometheus_${AZ_MONITOR_WORKSPACE_NAME} and query max_dimension_rainfall_histogram_bucket"
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

run_phases preview setup amw grafana cluster dashboards customize podmonitor cleanup
