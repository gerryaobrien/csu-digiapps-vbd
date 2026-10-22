#!/usr/bin/env bash
# End-to-end test runner for Module 1 of the WSPlus Kubernetes Technical Briefing.
# Walks every exercise in LOD/Labs/instructions.md (Module 1).
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module1.sh                 # run all phases
#   LAB_INSTANCE=999001 ./test-module1.sh setup           # only RG + AKS
#   LAB_INSTANCE=999001 ./test-module1.sh pods labels     # specific phases
#   LAB_INSTANCE=999001 ./test-module1.sh cleanup         # delete cluster + RG
#
# Phases (in order): providers setup pods labels deploy services configmaps cleanup
#
# Env overrides:
#   LAB_INSTANCE   (default 999001)  - 6-digit Skillable-style id
#   RESOURCE_GROUP (default azure-rg)
#   LOCATION       (default eastus2)
#   VM_SKU         (default Standard_D2as_v5)
#   PAUSE          (default 1)       - 1 = pause between exercises, 0 = no pause
#   TAG_SUB        (default 1)       - 1 = tag subscription with LabInstance, 0 = skip

set -euo pipefail

LAB_INSTANCE="${LAB_INSTANCE:-999001}"
RESOURCE_GROUP="${RESOURCE_GROUP:-azure-rg}"
LOCATION="${LOCATION:-eastus2}"
VM_SKU="${VM_SKU:-Standard_D2as_v5}"
PAUSE="${PAUSE:-1}"
TAG_SUB="${TAG_SUB:-1}"
AKS_NAME="aks-${LAB_INSTANCE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../assets/Module1"

c_blue=$'\033[1;34m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_off=$'\033[0m'
say()   { printf "%s==>%s %s\n" "$c_blue"   "$c_off" "$*"; }
ok()    { printf "%s[OK]%s %s\n"  "$c_green"  "$c_off" "$*"; }
warn()  { printf "%s[!!]%s %s\n"  "$c_yellow" "$c_off" "$*"; }
fail()  { printf "%s[XX]%s %s\n"  "$c_red"    "$c_off" "$*" >&2; exit 1; }

pause() {
  [[ "$PAUSE" == "1" ]] || return 0
  printf "\n%s-- press Enter to continue, Ctrl-C to abort --%s " "$c_yellow" "$c_off"
  read -r _
}

require() {
  for c in "$@"; do command -v "$c" >/dev/null || fail "missing command: $c"; done
}

# ---------- phases ----------

phase_providers() {
  say "Registering Azure resource providers (async; fire-and-forget)"
  for ns in Microsoft.Storage Microsoft.Compute Microsoft.Network Microsoft.Monitor \
            Microsoft.Insights Microsoft.ManagedIdentity Microsoft.OperationalInsights \
            Microsoft.OperationsManagement Microsoft.KeyVault Microsoft.ContainerRegistry \
            Microsoft.ContainerService Microsoft.Kubernetes; do
    az provider register --namespace "$ns" --consent-to-permissions >/dev/null 2>&1 || \
      az provider register --namespace "$ns" >/dev/null
  done
  ok "Provider registration kicked off"
}

phase_setup() {
  say "Lab vars: RG=$RESOURCE_GROUP LOCATION=$LOCATION SKU=$VM_SKU AKS=$AKS_NAME LabInstance=$LAB_INSTANCE"

  if [[ "$TAG_SUB" == "1" ]]; then
    local sub_id; sub_id="$(az account show --query id -o tsv)"
    say "Tagging subscription $sub_id with LabInstance=$LAB_INSTANCE (to satisfy skillable-acp.json)"
    az tag update --resource-id "/subscriptions/$sub_id" --operation merge \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
    ok "Subscription tagged"
  fi

  if az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1; then
    warn "Resource group $RESOURCE_GROUP already exists, reusing"
  else
    say "Creating resource group $RESOURCE_GROUP in $LOCATION"
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION" \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
    ok "RG created"
  fi

  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists, reusing"
  else
    say "Creating AKS $AKS_NAME (~5-10 min)"
    az aks create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$AKS_NAME" \
      --node-count 2 \
      --node-vm-size "$VM_SKU" \
      --generate-ssh-keys \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
    ok "AKS created"
  fi

  say "Fetching kubeconfig"
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
  ok "Cluster reachable"
  pause
}

phase_pods() {
  say "Exercise: Creating a Pod Declaratively"
  kubectl apply -f "$ASSETS/simple-pod.yaml"
  kubectl apply -f "$ASSETS/simple-pod2.yaml"
  kubectl wait --for=condition=Ready pod/nginx-pod --timeout=120s
  kubectl get pods --show-labels

  say "Filter pods by label kind=web"
  kubectl get pod -l kind=web

  say "Filter pods by label kind=db (expect empty)"
  kubectl get pod -l kind=db || true

  say "Export Pod definition to YAML"
  kubectl get pod nginx-pod -o yaml > /tmp/mypod.yaml
  ok "wrote /tmp/mypod.yaml ($(wc -l </tmp/mypod.yaml) lines)"
  pause
}

phase_labels() {
  say "Exercise: Working with Labels"
  kubectl label pod nginx-pod health=fair --overwrite
  kubectl get pods nginx-pod --show-labels

  say "Update existing label kind=web -> kind=db"
  kubectl label pod nginx-pod kind=db --overwrite
  kubectl get pods --show-labels

  say "Delete label health from nginx-pod"
  kubectl label pod nginx-pod health- || true
  kubectl label pod --all health- || true
  kubectl get pods --show-labels

  say "Delete pods matching label target=dev"
  kubectl delete pod -l target=dev --ignore-not-found
  pause
}

phase_deploy() {
  say "Exercise: Working with Deployments"
  kubectl apply -f "$ASSETS/ng-dep.yaml"
  kubectl apply -f "$ASSETS/ng-svc.yaml"
  kubectl rollout status deploy/ng-dep --timeout=180s
  kubectl get all --show-labels

  say "Wait for LoadBalancer external IP (up to 5 min)"
  for i in $(seq 1 30); do
    ip="$(kubectl get svc ng-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [[ -n "${ip:-}" ]] && break
    printf "."
    sleep 10
  done
  echo
  if [[ -n "${ip:-}" ]]; then ok "ng-svc external IP: http://$ip"; else warn "no external IP yet"; fi

  say "Update image to nginx:2.0"
  kubectl set image deployment/ng-dep nginx=k8slab/nginx:2.0
  kubectl rollout status deploy/ng-dep --timeout=180s
  kubectl describe deployment ng-dep | grep -E 'Image:|Replicas:' || true
  kubectl get all

  say "Rollback deployment"
  kubectl rollout history deploy/ng-dep
  kubectl rollout undo deploy/ng-dep
  kubectl rollout status deploy/ng-dep --timeout=180s

  say "Cleanup deployment + service"
  kubectl delete deployment ng-dep --ignore-not-found
  kubectl delete service    ng-svc --ignore-not-found
  pause
}

phase_services() {
  say "Exercise: Working with Services (sample-dep + sample-svc)"
  kubectl apply -f "$ASSETS/sample-dep.yaml"
  kubectl apply -f "$ASSETS/sample-svc.yaml"
  kubectl rollout status deploy/sample-dep --timeout=180s || true
  kubectl get pods --show-labels
  kubectl get svc -o wide
  pause

  say "Cleanup sample"
  kubectl delete deployment sample-dep --ignore-not-found
  kubectl delete service    sample-svc --ignore-not-found
}

phase_configmaps() {
  say "Exercise: Ephemeral Volumes, Secrets and ConfigMaps (MySQL multi-container)"
  kubectl apply -f "$ASSETS/mysql-initdb-cm.yaml"
  kubectl apply -f "$ASSETS/mysql-cnf-cm.yaml"
  kubectl apply -f "$ASSETS/mysql-dep.yaml"

  say "Wait for mysql-dep pod"
  kubectl rollout status deploy/mysql-dep --timeout=300s
  pod="$(kubectl get pod -l app=mysql-dep -o jsonpath='{.items[0].metadata.name}' 2>/dev/null \
        || kubectl get pod -o jsonpath='{.items[?(@.spec.containers[*].name=="mysql")].metadata.name}' | awk '{print $1}')"
  [[ -n "$pod" ]] || fail "could not locate mysql pod"
  ok "mysql pod: $pod"

  say "Tail logreader sidecar for 8s"
  ( kubectl logs -c logreader -f "$pod" & echo $! >/tmp/.lr.pid ) >/tmp/lr.log 2>&1 || true
  sleep 2

  say "Run a query against mysql container"
  kubectl exec -c mysql "$pod" -- bash -c 'mysql -e "use sample; select * from friends;"' || true
  sleep 6
  if [[ -f /tmp/.lr.pid ]]; then kill "$(cat /tmp/.lr.pid)" 2>/dev/null || true; rm -f /tmp/.lr.pid; fi
  ok "logreader output (last 20 lines):"
  tail -n 20 /tmp/lr.log || true

  say "Cleanup mysql"
  kubectl delete -f "$ASSETS/mysql-dep.yaml" --ignore-not-found
  kubectl delete -f "$ASSETS/mysql-cnf-cm.yaml" --ignore-not-found
  kubectl delete -f "$ASSETS/mysql-initdb-cm.yaml" --ignore-not-found
  kubectl delete pod nginx-pod nginx-pod2 --ignore-not-found
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

# ---------- driver ----------

require az kubectl

phases=("$@")
if [[ ${#phases[@]} -eq 0 ]]; then
  phases=(providers setup pods labels deploy services configmaps)
fi

for p in "${phases[@]}"; do
  case "$p" in
    providers)  phase_providers ;;
    setup)      phase_setup ;;
    pods)       phase_pods ;;
    labels)     phase_labels ;;
    deploy)     phase_deploy ;;
    services)   phase_services ;;
    configmaps) phase_configmaps ;;
    cleanup)    phase_cleanup ;;
    *)          fail "unknown phase: $p" ;;
  esac
done

ok "Module 1 phases done: ${phases[*]}"
