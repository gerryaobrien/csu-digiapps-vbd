#!/usr/bin/env bash
# Shared helpers for the WSPlus Kubernetes Technical Briefing module test scripts.
# Source this from each test-module*.sh.

set -euo pipefail

LAB_INSTANCE="${LAB_INSTANCE:-999001}"
RESOURCE_GROUP="${RESOURCE_GROUP:-azure-rg}"
LOCATION="${LOCATION:-eastus2}"
VM_SKU="${VM_SKU:-Standard_D2as_v5}"
PAUSE="${PAUSE:-1}"
TAG_SUB="${TAG_SUB:-1}"
AKS_NAME="${AKS_NAME:-aks-${LAB_INSTANCE}}"

c_blue=$'\033[1;34m'; c_green=$'\033[1;32m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_off=$'\033[0m'
say()  { printf "%s==>%s %s\n" "$c_blue"   "$c_off" "$*"; }
ok()   { printf "%s[OK]%s %s\n"  "$c_green"  "$c_off" "$*"; }
warn() { printf "%s[!!]%s %s\n"  "$c_yellow" "$c_off" "$*"; }
fail() { printf "%s[XX]%s %s\n"  "$c_red"    "$c_off" "$*" >&2; exit 1; }

pause() {
  [[ "$PAUSE" == "1" ]] || return 0
  printf "\n%s-- press Enter to continue, Ctrl-C to abort --%s " "$c_yellow" "$c_off"
  read -r _
}

# Prompt y/N. Returns 0 for yes, 1 for no. Honors AUTO_DELETE_RG=1 (yes) / 0 (no) for non-interactive runs.
confirm() {
  local prompt="${1:-Are you sure?}"
  if [[ "${AUTO_DELETE_RG:-}" == "1" ]]; then return 0; fi
  if [[ "${AUTO_DELETE_RG:-}" == "0" ]]; then return 1; fi
  local ans
  printf "\n%s%s [y/N]:%s " "$c_yellow" "$prompt" "$c_off"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Cleanup helper: optionally delete the whole RG, otherwise just delete the AKS cluster.
cleanup_rg_or_cluster() {
  local rg="${1:-$RESOURCE_GROUP}"
  local aks="${2:-$AKS_NAME}"
  if confirm "Delete entire resource group '$rg' (removes ALL resources in it)?"; then
    say "Deleting resource group $rg (no-wait)"
    az group delete -n "$rg" --yes --no-wait || true
  else
    say "Keeping resource group $rg. Deleting only AKS cluster $aks (no-wait)"
    az aks delete -g "$rg" -n "$aks" --yes --no-wait || true
  fi
}


require() {
  for c in "$@"; do command -v "$c" >/dev/null || fail "missing command: $c"; done
}

tag_subscription() {
  [[ "$TAG_SUB" == "1" ]] || return 0
  local sub_id; sub_id="$(az account show --query id -o tsv)"
  say "Tagging subscription $sub_id with LabInstance=$LAB_INSTANCE"
  az tag update --resource-id "/subscriptions/$sub_id" --operation merge \
    --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  ok "Subscription tagged"
}

ensure_rg() {
  local rg="${1:-$RESOURCE_GROUP}"
  if az group show -n "$rg" >/dev/null 2>&1; then
    warn "Resource group $rg already exists, reusing"
  else
    say "Creating resource group $rg in $LOCATION"
    az group create -n "$rg" -l "$LOCATION" --tags "LabInstance=$LAB_INSTANCE" >/dev/null
    ok "RG created"
  fi
}

# Run the listed phases in order. Defaults: every phase known to the script.
run_phases() {
  local available=("$@")
  local requested=("${SCRIPT_PHASES[@]}")
  if [[ ${#requested[@]} -eq 0 ]]; then requested=("${available[@]}"); fi
  for p in "${requested[@]}"; do
    local fn="phase_${p}"
    if declare -F "$fn" >/dev/null; then
      say "── Phase: $p ──"
      "$fn"
      ok "Phase $p complete"
      pause
    else
      fail "unknown phase: $p (available: ${available[*]})"
    fi
  done
}
