#!/usr/bin/env bash
# Module 3.b: AKS Ingress with Application Gateway for Containers (AGC)
# Uses the AKS *add-on* (--enable-application-load-balancer) — the simplest
# install path. The add-on creates and federates its own MSI in the MC RG
# with all required role assignments and an auto-delegated `aks-appgateway`
# subnet. Controller pods run in `kube-system`.
#
# Docs: https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module3b-agc.sh                 # full run, dedicated cluster
#   LAB_INSTANCE=999001 ./test-module3b-agc.sh reset preview setup provision gateway app test
#   LAB_INSTANCE=999001 ./test-module3b-agc.sh cleanup
#
# Reuse an existing cluster:
#   AKS_NAME=aks-999001 LAB_INSTANCE=999001 ./test-module3b-agc.sh setup provision gateway app test
#   (skip `cleanup` if you don't want to wipe the RG)
#
# Phases: reset preview setup provision gateway app test cleanup
#
# `reset` removes leftovers from prior helm- or extension-based attempts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

# AKS_NAME may be overridden via env to point at an existing cluster
# (e.g. the Module 1 cluster aks-${LAB_INSTANCE}). Defaults to a dedicated
# cluster for this lab.
AKS_NAME="${AKS_NAME:-aks-agc-${LAB_INSTANCE}}"
CONTROLLER_NAMESPACE="kube-system"  # add-on installs ALB controller in kube-system
LEGACY_IDENTITY_NAME="azure-alb-identity"
LEGACY_HELM_NAMESPACE="azure-alb-helm"
LEGACY_EXT_CTRL_NAMESPACE="azure-alb-system"
LEGACY_EXTENSION_NAME="azure-alb-controller"

phase_reset() {
  say "Cleaning up artefacts from prior helm- or extension-based installs"
  if command -v helm >/dev/null 2>&1; then
    helm uninstall alb-controller -n "$LEGACY_HELM_NAMESPACE" >/dev/null 2>&1 || true
  fi
  kubectl delete ns "$LEGACY_HELM_NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete ns "$LEGACY_EXT_CTRL_NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete ns alb-test-infra --ignore-not-found --wait=false >/dev/null 2>&1 || true

  az k8s-extension delete -g "$RESOURCE_GROUP" --cluster-type managedClusters \
    --cluster-name "$AKS_NAME" --name "$LEGACY_EXTENSION_NAME" --yes --force >/dev/null 2>&1 || true

  if az identity show -g "$RESOURCE_GROUP" -n "$LEGACY_IDENTITY_NAME" >/dev/null 2>&1; then
    say "Deleting legacy identity $LEGACY_IDENTITY_NAME"
    local legacyPid
    legacyPid="$(az identity show -g "$RESOURCE_GROUP" -n "$LEGACY_IDENTITY_NAME" --query principalId -o tsv 2>/dev/null || true)"
    az identity delete -g "$RESOURCE_GROUP" -n "$LEGACY_IDENTITY_NAME" >/dev/null 2>&1 || true
    if [[ -n "$legacyPid" ]]; then
      while read -r raId; do
        [[ -n "$raId" ]] && az role assignment delete --ids "$raId" >/dev/null 2>&1 || true
      done < <(az role assignment list --assignee "$legacyPid" --query '[].id' -o tsv 2>/dev/null || true)
    fi
  fi
  ok "Reset complete"
}

phase_preview() {
  say "Registering preview features and CLI extensions"
  az extension add --name aks-preview --upgrade --only-show-errors >/dev/null 2>&1 || true
  az extension add --name alb         --upgrade --only-show-errors >/dev/null 2>&1 || true
  for ns in Microsoft.ContainerService Microsoft.Network Microsoft.NetworkFunction Microsoft.ServiceNetworking; do
    az provider register --namespace "$ns" >/dev/null 2>&1 || true
  done
  az feature register --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview        >/dev/null 2>&1 || true
  az feature register --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview  >/dev/null 2>&1 || true

  say "Waiting for feature flags to be Registered (can take several minutes)"
  for f in ManagedGatewayAPIPreview ApplicationLoadBalancerPreview; do
    for i in $(seq 1 60); do
      local state
      state="$(az feature show --namespace Microsoft.ContainerService --name "$f" --query properties.state -o tsv 2>/dev/null || echo Pending)"
      [[ "$state" == "Registered" ]] && { ok "$f Registered"; break; }
      sleep 10
    done
  done
  az provider register --namespace Microsoft.ContainerService >/dev/null 2>&1 || true
}

phase_setup() {
  require az kubectl curl
  tag_subscription
  ensure_rg

  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists — enabling add-ons via update"
    az aks update -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
      --enable-oidc-issuer --enable-workload-identity \
      --enable-gateway-api --enable-application-load-balancer >/dev/null
  else
    say "Creating AKS $AKS_NAME with Gateway API + ALB add-ons (~10 min)"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" --location "$LOCATION" \
      --node-vm-size Standard_D2s_v5 \
      --network-plugin azure \
      --enable-oidc-issuer --enable-workload-identity \
      --enable-gateway-api --enable-application-load-balancer \
      --generate-ssh-keys --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null

  say "Waiting for ALB controller pods in $CONTROLLER_NAMESPACE"
  for i in $(seq 1 60); do
    if kubectl -n "$CONTROLLER_NAMESPACE" get deploy alb-controller >/dev/null 2>&1; then break; fi
    sleep 5
  done
  kubectl -n "$CONTROLLER_NAMESPACE" rollout status deploy/alb-controller --timeout=300s || true
  kubectl get gatewayclass azure-alb-external -o yaml | head -30 || true
  ok "ALB add-on installed"
}

phase_provision() {
  local mcRG vnetName albSubnetId
  mcRG="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query nodeResourceGroup -o tsv)"
  vnetName="$(az network vnet list -g "$mcRG" --query '[0].name' -o tsv)"
  say "Locating AGC-delegated subnet in $mcRG/$vnetName"
  for i in $(seq 1 30); do
    albSubnetId="$(az network vnet subnet list -g "$mcRG" --vnet-name "$vnetName" \
      --query "[?delegations[?serviceName=='Microsoft.ServiceNetworking/trafficControllers']].id | [0]" -o tsv 2>/dev/null || true)"
    [[ -n "$albSubnetId" ]] && break
    sleep 5
  done
  [[ -z "$albSubnetId" ]] && fail "Could not locate AGC-delegated subnet (expected aks-appgateway) in $mcRG"
  ok "AGC subnet: $albSubnetId"

  kubectl create ns alb-test-infra --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -f - <<EOF
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb-test
  namespace: alb-test-infra
spec:
  associations:
  - $albSubnetId
EOF
  say "Waiting for AGC ApplicationLoadBalancer to deploy (typically 5-10 min — Azure provisions the trafficController and binds it to the aks-appgateway subnet)"
  for i in $(seq 1 60); do
    local state
    state="$(kubectl get applicationloadbalancer alb-test -n alb-test-infra -o jsonpath='{.status.conditions[?(@.type=="Deployment")].status}' 2>/dev/null || true)"
    [[ "$state" == "True" ]] && break
    sleep 10
  done
  kubectl get applicationloadbalancer alb-test -n alb-test-infra
}

phase_gateway() {
  kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: alb-test-infra
  annotations:
    alb.networking.azure.io/alb-namespace: alb-test-infra
    alb.networking.azure.io/alb-name: alb-test
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http-listener
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
EOF
  say "Waiting for Gateway to be Programmed"
  for i in $(seq 1 60); do
    local fqdn
    fqdn="$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
    [[ -n "$fqdn" ]] && { echo "FQDN: $fqdn"; return; }
    sleep 5
  done
  warn "Gateway FQDN not assigned yet"
}

phase_app() {
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: my-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: my-app}}
  template:
    metadata: {labels: {app: my-app}}
    spec:
      containers:
      - {name: my-app, image: nginx, ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: my-app}
spec:
  selector: {app: my-app}
  ports: [{port: 80, targetPort: 80}]
EOF
  local fqdn
  fqdn="$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}')"
  [[ -z "$fqdn" ]] && fail "Gateway FQDN not ready"
  kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: my-app-route, namespace: default}
spec:
  parentRefs: [{name: gateway-01}]
  hostnames: ["$fqdn"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /}}]
    backendRefs: [{name: my-app, port: 80}]
EOF
  ok "App + HTTPRoute deployed; frontend FQDN: $fqdn"
}

phase_test() {
  local fqdn code
  fqdn="$(kubectl get gateway gateway-01 -o jsonpath='{.status.addresses[0].value}')"
  say "Waiting up to 3 min for AGC to program the route"
  for i in $(seq 1 36); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$fqdn/" || echo 000)"
    [[ "$code" == "200" ]] && { ok "200 OK from http://$fqdn/"; return; }
    sleep 5
  done
  warn "Route not yet returning 200 — last code $code; try again in a minute"
}

phase_cleanup() {
  cleanup_rg_or_cluster
}

run_phases reset preview setup provision gateway app test cleanup
