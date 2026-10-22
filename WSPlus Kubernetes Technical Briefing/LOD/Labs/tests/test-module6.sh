#!/usr/bin/env bash
# Module 6: Storage on AKS — Azure Disks (manual + dynamic), Azure Files,
# and Azure Container Storage (ACStor) with replicated ephemeral NVMe.
#
# Reuses an existing AKS or creates one. Patches the disk-pv.yaml /
# azurefile-pv.yaml templates with real Azure resource IDs at runtime,
# writing patched copies into a temp dir to avoid mutating repo assets.
#
# Usage:
#   LAB_INSTANCE=999001 ./test-module6.sh
#   LAB_INSTANCE=999001 ./test-module6.sh acstor          # only the ACStor exercise
#   LAB_INSTANCE=999001 ./test-module6.sh cleanup
#
# Phases: setup ns disk file dynamic acstor cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PHASES=("$@")
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

ASSETS="$SCRIPT_DIR/../assets/Module6"
WORK_DIR="${TMPDIR:-/tmp}/m6-${LAB_INSTANCE}"; mkdir -p "$WORK_DIR"
NS="storagelab"
ACSTOR_NODEPOOL_NAME="${ACSTOR_NODEPOOL_NAME:-acstorpool}"
ACSTOR_VM_SIZE="${ACSTOR_VM_SIZE:-Standard_L8s_v3}"
INITIALS="${YOUR_INITIALS:-tst}"

phase_setup() {
  require az kubectl curl
  tag_subscription
  ensure_rg
  if ! az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" >/dev/null 2>&1; then
    say "Creating AKS $AKS_NAME — ~10 min"
    az aks create -g "$RESOURCE_GROUP" -n "$AKS_NAME" --location "$LOCATION" \
      --node-count 2 --node-vm-size "$VM_SKU" --generate-ssh-keys \
      --tags "LabInstance=$LAB_INSTANCE" >/dev/null
  else
    warn "Reusing $AKS_NAME"
  fi
  az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing >/dev/null
  kubectl get nodes
}

phase_ns() {
  kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
  kubectl config set-context --current --namespace "$NS"
}

phase_disk() {
  local mc disk_id
  mc="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query nodeResourceGroup -o tsv)"
  say "Creating Azure Disk MyManagedDisk in $mc"
  if ! az disk show -g "$mc" -n MyManagedDisk >/dev/null 2>&1; then
    az disk create -g "$mc" -n MyManagedDisk --size-gb 128 --sku Premium_LRS \
      --location "$LOCATION" --os-type Linux >/dev/null
  fi
  disk_id="$(az disk show -g "$mc" -n MyManagedDisk --query id -o tsv)"
  ok "Disk: $disk_id"

  cp "$ASSETS/disk-pv.yaml" "$WORK_DIR/disk-pv.yaml"
  sed -i "s|/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/disks/<disk-name>|$disk_id|" "$WORK_DIR/disk-pv.yaml"
  kubectl apply -f "$WORK_DIR/disk-pv.yaml"
  kubectl apply -f "$ASSETS/disk-pvc.yaml"
  kubectl get pv,pvc -n "$NS"
  kubectl apply -f "$ASSETS/disk-pod.yaml"
  kubectl wait --for=condition=Ready pod/nginx-pod -n "$NS" --timeout=180s
  kubectl exec -n "$NS" nginx-pod -- sh -c "cd /sharedfolder && touch abc123.txt && ls -l"
  kubectl delete pod/nginx-pod -n "$NS"
  sleep 30
  az disk show -g "$mc" -n MyManagedDisk --query diskState -o tsv
  kubectl apply -f "$ASSETS/disk-pod.yaml"
  kubectl wait --for=condition=Ready pod/nginx-pod -n "$NS" --timeout=180s
  kubectl exec -n "$NS" nginx-pod -- sh -c "ls -l /sharedfolder"
}

phase_file() {
  local sa share key
  sa="sa${INITIALS}${RANDOM}"
  share="share${INITIALS}"
  say "Creating Storage Account $sa + share $share"
  az storage account create -g "$RESOURCE_GROUP" -n "$sa" --sku Standard_LRS --location "$LOCATION" >/dev/null
  local cs; cs="$(az storage account show-connection-string -g "$RESOURCE_GROUP" -n "$sa" -o tsv)"
  az storage share create --name "$share" --connection-string "$cs" >/dev/null
  key="$(az storage account keys list -g "$RESOURCE_GROUP" --account-name "$sa" --query "[0].value" -o tsv)"

  kubectl -n "$NS" create secret generic azure-secret \
    --from-literal=azurestorageaccountname="$sa" \
    --from-literal=azurestorageaccountkey="$key" \
    --dry-run=client -o yaml | kubectl apply -f -

  cp "$ASSETS/azurefile-pv.yaml" "$WORK_DIR/azurefile-pv.yaml"
  sed -i "s|<resource-group>|$RESOURCE_GROUP|; s|<share-name>|$share|; s|unique-volume-id|${RESOURCE_GROUP}#${sa}#${share}|" "$WORK_DIR/azurefile-pv.yaml"
  # azure-secret was just created in $NS; ensure nodeStageSecretRef points there
  sed -i "s|namespace: default|namespace: $NS|" "$WORK_DIR/azurefile-pv.yaml"
  kubectl apply -f "$WORK_DIR/azurefile-pv.yaml"
  kubectl apply -f "$ASSETS/azurefile-pvc.yaml"
  kubectl apply -f "$ASSETS/pvc-pod.yaml"
  kubectl wait --for=condition=Ready pod/pvc-pod -n "$NS" --timeout=300s || true
  kubectl exec -n "$NS" pvc-pod -- sh -c "cd /sharedfolder && touch from-pvc.txt && ls -l"
  kubectl apply -f "$ASSETS/deployment.yaml"
  kubectl rollout status -n "$NS" deploy/nginx-deployment --timeout=300s || true
  kubectl get pods -n "$NS" -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
}

phase_dynamic() {
  kubectl apply -f "$ASSETS/azure-pvc.yaml"
  kubectl apply -f "$ASSETS/azure-pod.yaml"
  kubectl wait --for=condition=Ready pod/mypod -n "$NS" --timeout=300s
  kubectl describe pvc azure-managed-disk -n "$NS" | tail -20
  kubectl exec -n "$NS" mypod -- sh -c "cd /sharedfolder && date > now && ls -l"
  kubectl delete -f "$ASSETS/azure-pod.yaml"
  kubectl apply -f "$ASSETS/azure-pod.yaml"
  kubectl wait --for=condition=Ready pod/mypod -n "$NS" --timeout=300s
  kubectl exec -n "$NS" mypod -- sh -c "ls -l /sharedfolder"
  kubectl delete -f "$ASSETS/azure-pod.yaml"
  kubectl delete -f "$ASSETS/azure-pvc.yaml"
}

phase_acstor() {
  az extension add -n k8s-extension --upgrade --only-show-errors >/dev/null 2>&1 || true
  if az aks nodepool show --cluster-name "$AKS_NAME" -g "$RESOURCE_GROUP" -n "$ACSTOR_NODEPOOL_NAME" >/dev/null 2>&1; then
    warn "Node pool $ACSTOR_NODEPOOL_NAME already exists"
  else
    say "Adding ACStor node pool $ACSTOR_NODEPOOL_NAME ($ACSTOR_VM_SIZE × 3) — quota required"
    az aks nodepool add --cluster-name "$AKS_NAME" -g "$RESOURCE_GROUP" \
      -n "$ACSTOR_NODEPOOL_NAME" --node-vm-size "$ACSTOR_VM_SIZE" --node-count 3 || \
      fail "node pool add failed (quota? try ACSTOR_VM_SIZE=Standard_L8s_v2)"
  fi

  say "Enabling Azure Container Storage (~20 min)"
  az aks update -g "$RESOURCE_GROUP" -n "$AKS_NAME" \
    --enable-azure-container-storage ephemeralDisk \
    --azure-container-storage-nodepools "$ACSTOR_NODEPOOL_NAME" \
    --storage-pool-option NVMe \
    --ephemeral-disk-volume-type PersistentVolumeWithAnnotation || \
    fail "ACStor enable failed"

  kubectl get pods -n acstor
  kubectl delete sp -n acstor ephemeraldisk-nvme --ignore-not-found

  kubectl apply -f - <<'EOF'
apiVersion: containerstorage.azure.com/v1
kind: StoragePool
metadata: {name: ephemeraldisk-nvme, namespace: acstor}
spec:
  poolType:
    ephemeralDisk: {diskType: nvme, replicas: 3}
EOF

  for i in $(seq 1 30); do
    kubectl get sc acstor-ephemeraldisk-nvme >/dev/null 2>&1 && break
    sleep 10
  done
  kubectl get sc

  curl -fsSL -o "$WORK_DIR/acstor-mysql-config-services.yaml" \
    https://gist.githubusercontent.com/pauldotyu/f459c834558fd83a6254fae0eb23b1e6/raw/ad1b5db804060b18b3ea123db9189f1a2d56414b/acstor-mysql-config-services.yaml
  curl -fsSL -o "$WORK_DIR/acstor-mysql-statefulset.yaml" \
    https://gist.githubusercontent.com/pauldotyu/f7539f4fc991cf5fc3ecb22383cb227c/raw/274b0747f1094db53869bcb0eb25faccf0f37a6a/acstor-mysql-statefulset.yaml
  kubectl apply -f "$WORK_DIR/acstor-mysql-config-services.yaml"
  kubectl apply -f "$WORK_DIR/acstor-mysql-statefulset.yaml"
  say "Waiting for mysql-0 pod"
  kubectl wait --for=condition=Ready pod/mysql-0 --timeout=600s -n default || \
    kubectl wait --for=condition=Ready pod/mysql-0 --timeout=300s

  kubectl run mysql-client --image=mysql:8.0 -i --rm --restart=Never -- \
    mysql -h mysql-0.mysql <<'EOF'
CREATE DATABASE IF NOT EXISTS school;
CREATE TABLE IF NOT EXISTS school.students (RollNumber INT, Name VARCHAR(250));
INSERT INTO school.students VALUES (1, 'Student1');
INSERT INTO school.students VALUES (2, 'Student2');
EOF
  kubectl run mysql-client --image=mysql:8.0 -i --rm --restart=Never -- \
    mysql -h mysql-read -e "SELECT * FROM school.students" || true

  say "Triggering failover by deleting the node hosting mysql-0"
  local node_count node pod
  node_count="$(az aks nodepool show -g "$RESOURCE_GROUP" --cluster-name "$AKS_NAME" -n "$ACSTOR_NODEPOOL_NAME" --query count -o tsv)"
  az aks nodepool scale -g "$RESOURCE_GROUP" --cluster-name "$AKS_NAME" \
    -n "$ACSTOR_NODEPOOL_NAME" --node-count "$((node_count+1))" --no-wait
  pod="$(kubectl get pods -l app=mysql -o custom-columns=:metadata.name --no-headers | head -1)"
  node="$(kubectl get pod "$pod" -o jsonpath='{.spec.nodeName}')"
  say "Deleting node $node (will trigger reschedule)"
  kubectl delete node "$node"
  sleep 60
  kubectl get pods -l app=mysql -o wide || true

  kubectl run mysql-client --image=mysql:8.0 -i --rm --restart=Never -- \
    mysql -h mysql-0.mysql <<'EOF'
INSERT INTO school.students VALUES (3, 'Student3');
INSERT INTO school.students VALUES (4, 'Student4');
EOF
  kubectl run mysql-client --image=mysql:8.0 -i --rm --restart=Never -- \
    mysql -h mysql-read -e "SELECT * FROM school.students" || true
}

phase_cleanup() {
  kubectl delete ns "$NS" --ignore-not-found
  cleanup_rg_or_cluster
}

run_phases setup ns disk file dynamic acstor cleanup
