# Disaster Recovery

This repository now uses Kubernetes resources for disaster recovery rather than local helper tasks.

The recovery layers are:

- `Git`: source of truth for Talos, Argo, and app manifests
- `Velero`: cluster objects and file-system volume backups
- `Talos etcd CronJob`: control-plane snapshots uploaded to S3
- `VolSync`: optional app-level PVC backups for tighter RPOs

## Kubernetes Backup Resources

The DR manifests live in [`kubernetes/apps/storage/velero/config`](/Users/aj/Projects/home-lab/kubernetes/apps/storage/velero/config):

- `velero-s3-creds.yaml`
- `create-bucket-job.yaml`
- `talos-etcd-backup-s3-creds.yaml`
- `talos-etcd-backup-secret.yaml`
- `etcd-backup-cronjob.yaml`

What they do:

- Velero takes a full-cluster backup every day at `02:00`.
- `talos-etcd-backup` is created suspended and takes an `etcd` snapshot every day at `01:30` once enabled.
- Both backup flows store data in `s3.aknuk.dev` under the `kubernetes-backups` bucket.

## Required Preparation

Before syncing the Velero app, update [`talos-etcd-backup-secret.yaml`](/Users/aj/Projects/home-lab/kubernetes/apps/storage/velero/config/talos-etcd-backup-secret.yaml):

- replace `endpoints` and `nodes` with your control-plane addresses
- replace the placeholder `talosconfig` with the contents of `talos/clusterconfig/talosconfig`
- set `suspend: false` in [`etcd-backup-cronjob.yaml`](/Users/aj/Projects/home-lab/kubernetes/apps/storage/velero/config/etcd-backup-cronjob.yaml) after the secret is valid

If you do not want the Talos client config stored as a plain Secret in Git, convert that manifest to SOPS or ExternalSecret before applying it.

## Manual Kubernetes Backup

Create an on-demand cluster backup with a Kubernetes `Backup` resource:

```sh
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-$(date +%Y%m%d-%H%M%S)
  namespace: storage
spec:
  includedNamespaces:
    - '*'
  storageLocation: default
  ttl: 720h
  defaultVolumesToFsBackup: true
EOF
```

Check status:

```sh
kubectl get backups.velero.io -n storage
kubectl describe backup -n storage <backup-name>
```

## Manual Kubernetes Restore

Restore a full-cluster backup with a Kubernetes `Restore` resource:

```sh
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: storage
spec:
  backupName: <backup-name>
  existingResourcePolicy: update
EOF
```

Check status:

```sh
kubectl get restores.velero.io -n storage
kubectl describe restore -n storage <restore-name>
```

## Same Hardware Recovery

Use this when you are recovering onto the same machine or same node set.

1. Keep access to:
   - this Git repo
   - `age.key`
   - `talos/talsecret.sops.yaml`
   - the S3 bucket with Velero and `etcd` backups
2. Reinstall or boot Talos into maintenance mode.
3. Regenerate and apply Talos machine config.
4. Download the required `etcd` snapshot from S3 to your recovery workstation.
5. Recover the Talos control plane:

```sh
talosctl bootstrap \
  --nodes <bootstrap-node-ip> \
  --endpoints <bootstrap-node-ip> \
  --recover-from ./<snapshot-file>.db
```

6. Regenerate `kubeconfig` if needed.
7. Re-bootstrap base apps if Argo or core components are missing:

```sh
task bootstrap:apps
```

8. Apply a `Restore` resource for the required Velero backup.

## Different Hardware Recovery

Use this when IPs, MAC addresses, disks, or hosts have changed.

1. Update [`talos/talconfig.yaml`](/Users/aj/Projects/home-lab/talos/talconfig.yaml) with the new machine data.
2. Keep the same cluster identity and secrets if you want to recover into the same backup lineage.
3. Regenerate and apply Talos config to the new nodes.
4. Download the required `etcd` snapshot from S3.
5. Recover the control plane with `talosctl bootstrap --recover-from`.
6. Re-bootstrap base apps:

```sh
task bootstrap:apps
```

7. Apply a Velero `Restore` resource for the desired backup.

## Velero vs VolSync

- Use `Velero` for full-cluster DR and namespace recovery.
- Use `VolSync` for individual PVC migration or tighter backup schedules.
- Use Talos `etcd` snapshots when you need exact control-plane state recovery.
