# amun-longhorn

Longhorn distributed block storage for [amun-kubernetes](https://github.com/GonzaloAlvarez/amun-kubernetes).
Default StorageClass uses **3 replicas** (survives 2 simultaneous node failures).

Storage nodes (`longhorn_storage: true` in the inventory): `rpid0`..`rpid6`
(the 1TB SD cards). `rpid7`..`rpid10` are compute-only.

## Quick start

```sh
./deploy
```

This:

1. Installs Longhorn host requirements (`open-iscsi`, `nfs-common`, `util-linux`,
   `jq`) on storage-eligible nodes.
2. Enables the `iscsid` service.
3. Ensures `/var/lib/longhorn` exists on storage nodes.
4. Applies the Longhorn `HelmChart` CRD into `longhorn-system` (resolved
   in-cluster by k3s's Helm controller — no helm CLI needed locally).
5. Labels storage-eligible nodes with `node.longhorn.io/create-default-disk=true`.
6. Patches the default StorageClass for `numberOfReplicas: 3`.

Idempotent — re-run any time.

## Health check

```sh
# core CRDs
kubectl -n longhorn-system get nodes.longhorn.io -o wide
kubectl -n longhorn-system get volumes -o wide
kubectl -n longhorn-system get replicas -o wide
kubectl -n longhorn-system get engines

# quick "is anything degraded?"
kubectl -n longhorn-system get volumes \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.state}{"\t"}{.status.robustness}{"\n"}{end}'

# disk usage per node
kubectl -n longhorn-system get nodes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,SCHEDULABLE:.spec.allowScheduling,READY:.status.conditions[?(@.type=="Ready")].status'

# UI
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8000:80
open http://localhost:8000
```

## Common tasks

```sh
# Replace a failed Pi: install OS, run amun-kubernetes/deploy with the new node
# in inventory, then re-run ./deploy here. Longhorn auto-rebuilds replicas.

# Add a USB SSD to a storage node
ssh rpid3.lan sudo mkdir -p /mnt/longhorn-ssd
# mount persistently in /etc/fstab, then in Longhorn UI:
#   Node > rpid3 > Edit Node and Disks > add /mnt/longhorn-ssd

# Take a manual snapshot of a volume
kubectl -n longhorn-system create -f - <<'YAML'
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata: { name: my-snap, namespace: longhorn-system }
spec: { volume: <pvc-uuid-as-volume> }
YAML

# Set backup target (S3/NFS) — in UI: Setting > General > Backup Target
```

## Capacity math

7 storage nodes × ~954G usable = ~6.5TB raw.
3-replica → ~**2.1TB usable**, survives any 2 node losses concurrently.

## License

GNU GPL v3. Copyright (c) 2026 Gonzalo Alvarez.
