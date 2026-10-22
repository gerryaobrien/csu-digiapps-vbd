#!/usr/bin/env bash
# Module 3 / Lab 2: Advanced Container Networking Services (ACNS) on AKS.
# Creates a NEW cluster with Azure CNI Overlay + Cilium + L7, applies the
# demo app and FQDN/L7 policies, optionally installs Hubble CLI.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module3-acns.sh
#   LAB_INSTANCE=999001 ./test-module3-acns.sh cleanup
#
# Phases: setup deploy fqdn l7 hubble cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

ASSETS="$SCRIPT_DIR/../assets/Module3"
# Use a dedicated cluster name so it doesn't clash with M1/M2.
AKS_NAME="aks-acns-${LAB_INSTANCE}"

phase_setup() {
  require az kubectl curl
  tag_subscription
  ensure_rg
  if az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    warn "AKS $AKS_NAME already exists, reusing"
  else
    say "Creating ACNS-enabled AKS $AKS_NAME (Cilium + L7) — ~5-10 min"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" --location "$LOCATION" \
      --node-count 2 \
      --network-plugin azure --network-plugin-mode overlay \
      --network-dataplane cilium \
      --enable-acns --acns-advanced-networkpolicies L7 \
      --generate-ssh-keys --tags "LabInstance=$LAB_INSTANCE" >/dev/null
    ok "Cluster created"
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_deploy() {
  kubectl apply -f "$ASSETS/networking-demo-app.yaml"
  say "Waiting for demo pods Ready"
  kubectl -n acns-demo wait --for=condition=Ready pod --all --timeout=180s || true
  kubectl -n acns-demo get pods
  say "Baseline connectivity (everything allowed)"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "server: %{http_code}\n" http://http-server || true
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "example: %{http_code}\n" https://example.com || true
}

phase_fqdn() {
  kubectl apply -f "$ASSETS/networking-fqdn-policy.yaml"
  sleep 5
  say "Allowed FQDN should succeed"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "example: %{http_code}\n" https://example.com || true
  say "Disallowed FQDN should fail"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS --max-time 5 -o /dev/null -w "bing: %{http_code}\n" https://www.bing.com || echo "blocked (expected)"
}

phase_l7() {
  kubectl apply -f "$ASSETS/networking-l7-policy.yaml"
  sleep 5
  say "GET / (allowed)"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "GET /: %{http_code}\n" http://http-server/ || true
  say "GET /index.html (denied — expect 403)"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "GET /index.html: %{http_code}\n" http://http-server/index.html || true
  say "POST / (denied — expect 403)"
  kubectl -n acns-demo exec deploy/http-client -- curl -sS -X POST -o /dev/null -w "POST /: %{http_code}\n" http://http-server/ || true
}

phase_hubble() {
  if ! command -v hubble >/dev/null; then
    say "Installing Hubble CLI"
    local tmp; tmp="$(mktemp -d)"
    ( cd "$tmp" && curl -fsSL -O https://github.com/cilium/hubble/releases/latest/download/hubble-linux-amd64.tar.gz \
       && sudo tar xzf hubble-linux-amd64.tar.gz -C /usr/local/bin )
    rm -rf "$tmp"
  fi
  say "Port-forwarding Hubble Relay (background)"
  kubectl port-forward -n kube-system svc/hubble-relay 4245:443 >/dev/null 2>&1 &
  local pid=$!; sleep 3
  HUBBLE_SERVER=localhost:4245 HUBBLE_TLS_DISABLE=true hubble observe --namespace acns-demo --type l7 --last 20 || true
  kill "$pid" 2>/dev/null || true
}

phase_cleanup() {
  kubectl delete -f "$ASSETS/networking-l7-policy.yaml" --ignore-not-found
  kubectl delete -f "$ASSETS/networking-fqdn-policy.yaml" --ignore-not-found
  kubectl delete -f "$ASSETS/networking-demo-app.yaml" --ignore-not-found
  cleanup_rg_or_cluster
}

run_phases setup deploy fqdn l7 hubble cleanup
