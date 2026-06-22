# External cluster

I Run Ceph on Proxmox, so why not consume it in Kubernetes aswell.

## Prerequisites
- RBD Pool for K8S
- CephFS pool for K8S
- The network that Ceph uses as "public_network" accessible from K8S, I gave my nodes a second NIC in the network.


## Steps
- Run "create-external-cluster-resources.py" on your PVE host, or Ceph host. Make sure to adapt to your usecase. I ran with the parameters:
```bash
python3 create-external-cluster-resources.py --rbd-data-pool-name K8S  --namespace rook-ceph --format bash --cephfs-filesystem-name k8s-cephfs --v2-port-enable
```
Save the output somewhere nice.

- Run "import-external-cluster.sh". This will create the following resources(output based on my parameters to create-external-cluster-resources.py):
```bash
namespace/rook-ceph
secret/rook-ceph-mon
configmap/rook-ceph-mon-endpoints
configmap/external-cluster-user-command
secret/rook-csi-rbd-node
secret/rook-csi-rbd-provisioner
secret/rook-csi-cephfs-node
secret/rook-csi-cephfs-provisioner
storageclass.storage.k8s.io/ceph-rbd
storageclass.storage.k8s.io/cephfs
```

If you don't want to rerun these steps you can create and commit the resources to your repo.

- Now go ahead and apply operator, csi-drivers and cluster HelmReleases to the cluster.