<div align="center">

<img src="docs/assets/k8spega.png" align="center" width="400px" height="200px"/>

### Home-ops with K8s and friends 👪
Automated with [Flux](https://fluxcd.io), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)  🤖
</div>

# 📄 Overview
This is a monorepo for my selfhosted infrastructure in an attempt to escape the big cloud. Applying Infrastructure as Code (IaC) and GitOps as much as possible using the likes of [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Talos](https://www.talos.dev) and many more awesome tools while learning on the fly.

## ⛵ Kubernetes
I run a 3 node hyper-converged (HCI) [Talos](https://www.talos.dev) cluster on top of [Proxmox](https://www.proxmox.com/). Each node has three disks: one for the Proxmox installation, one serving as a Ceph OSD, and one passed through directly to the Talos VM. The same hosts run a [Ceph](https://ceph.io/) cluster which Kubernetes consumes via Rook-Ceph in external mode.

If you find this interesting and want to get started doing something similar I can strongly recommend taking a look at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)

### Core Components
- [Flux](https://fluxcd.io/): GitOps for Kubernetes, managed by [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator).
- [Cilium](https://github.com/cilium/cilium): eBPF-based internal Kubernetes container networking interface.
- [Cert-manager](https://github.com/cert-manager/cert-manager): Requests SSL certificates from [Let's Encrypt](https://letsencrypt.org/).
- [Envoy Gateway](https://github.com/envoyproxy/gateway): Gateway API implementation serving as the point of entry to the cluster.
- [External-DNS](https://github.com/kubernetes-sigs/external-dns): Automatically syncs DNS records, one instance towards Cloudflare and one towards my UDM Pro using the [UniFi webhook provider](https://github.com/kashalls/external-dns-unifi-webhook).
- [Cloudflared](https://github.com/cloudflare/cloudflared): Secure access to certain routes via Cloudflare tunnel.
- [Rook-Ceph](https://github.com/rook/rook): Consumes the external Ceph cluster running on the Proxmox hosts for persistent block and file storage.
- [Multus](https://github.com/k8snetworkplumbingwg/multus-cni): Attaches a dedicated VPN network to the pods that need it.
- [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg): PostgreSQL for applications, with backups handled by [Barman Cloud](https://github.com/cloudnative-pg/plugin-barman-cloud).
- [SOPS](https://github.com/getsops/sops): Managed secrets for Kubernetes which are committed to Git.
- [Spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.

### Directory
The repository should look something like this. (Subject to change)

```
📁 .github            # Github workflows and Renovate config
📁 bootstrap          # Contains necessary bootstrap components
📁 kubernetes
└── 📁 apps           # Contains all applications and resources that flux will apply
└── 📁 components     # Re-usable kustomize components
└── 📁 flux           # Core flux configuration
📁 scripts            # Useful scripts
📁 talos              # Talos configuration managed with talhelper
```

### Short workflow
[Flux](https://fluxcd.io/) watches over the cluster in my [kubernetes](https://github.com/s0undy/home-ops/tree/main/kubernetes) folder and makes changes based on the state of the repository.

Flux recursively searches the `kubernetes/` directory for the most top level `kustomization.yaml` per directory and applies all the resources listed in it. The `kustomization.yaml` generally only consists of a namespace and one or many Flux kustomizations (`ks.yaml`). The `ks.yaml` will reference a HelmRelease or other resources that will be applied and deployed to the cluster.

[Renovate](https://github.com/renovatebot/renovate) watches over the repo looking for dependency updates, such as new versions of containers and when they are found a pull-request is automagically created in this repository. [konflate](https://github.com/home-operations/konflate) renders a diff of the `HelmRelease` and `Kustomization` changes on every pull-request so I can see exactly what will change in the cluster. When I merge these pull-requests, Flux will detect changes to the repository and apply them to the cluster. Magic! ✨

## Network
<details>
  <summary>Click to view the network topology</summary>
  SoonTM
</details>

## 🌐 DNS

### Cluster/Public
In the cluster, I run [ExternalDNS](https://github.com/kubernetes-sigs/external-dns), which creates DNS records in Cloudflare for `HTTPRoutes` attached to the external gateway. Those routes are then reachable from the internet through a [Cloudflare tunnel](https://www.cloudflare.com/products/tunnel/).

### Home DNS
Devices on the LAN use my UDM Pro as their DNS server. A second instance of ExternalDNS uses the [ExternalDNS webhook provider for UniFi](https://github.com/kashalls/external-dns-unifi-webhook) to automagically create DNS records on the UDM Pro for `HTTPRoutes` attached to the internal gateway, allowing me to access resources published from the cluster.

## ☁️ Dependencies
Most of my infrastructure is self-hosted, however certain parts are easier and safer to run in the cloud.

| Service                                         | Use                                                               | Cost                |
|-------------------------------------------------|-------------------------------------------------------------------|---------------------|
| [Cloudflare](https://www.cloudflare.com/)       | DNS and Cloudflare tunnel                                         | Free                |
| [HOSTUP](https://hostup.se/)                    | Domain registrar                                                  | 125kr/year(12$)     |
| [GitHub](https://github.com/)                   | Git, CI/CD                                                        | Free                |
|                                                 |                                                                   | Total: ~12kr/mo(1$) |
---

## 🔧 Hardware
| Name               | Device                   | CPU      | Disks                                                       | RAM  | OS           | Purpose                             |
|--------------------|--------------------------|----------|-------------------------------------------------------------|------|--------------|-------------------------------------|
| Arx                | Lenovo ThinkCentre M920q | i5-8500T | 256GB SSD (PVE) / 1TB NVMe (Ceph OSD) / 128GB NVMe (Talos)  | 32GB | Proxmox      | PVE host, Ceph, VMs                 |
| JIT-TALOS-01       | VM on Arx                | 4vCPU    | 128GB NVME Direct passthrough                               | 24GB | Talos        | Kubernetes                          |
| Pax                | Lenovo ThinkCentre M720q | i5-9500T | 256GB SSD (PVE) / 1TB NVMe (Ceph OSD) / 256GB NVMe (Talos)  | 32GB | Proxmox      | PVE host, Ceph, VMs                 |
| JIT-TALOS-02       | VM on Pax                | 6vCPU    | 256GB NVME Direct passthrough                               | 24GB | Talos        | Kubernetes                          |
| Via                | Lenovo ThinkCentre M720q | i5-9500T | 256GB SSD (PVE) / 1TB NVMe (Ceph OSD) / 256GB NVMe (Talos)  | 32GB | Proxmox      | PVE host, Ceph, VMs                 |
| JIT-TALOS-03       | VM on Via                | 6vCPU    | 256GB NVM Direct passthrough                                | 24GB | Talos        | Kubernetes                          |
| JIT-Horrea         | Whitebox NAS             | G3900    | 4x2TB + 2x 3TB HDDs - 256GB NVME(OS)                        | 16GB | TrueNAS      | NAS                                 |
| Octo               | Raspberry 4 Model B      | -        | 64GB SD-card                                                | 4GB  | OctoPi       | OctoPi for my Ender 5 S1 3D-Printer |
| UDM-1              | UniFi Dream Machine Pro  | -        | -                                                           | -    | -            | Router, Firewall and DNS            |
| US XG 16           | UniFi US XG 16           | -        | -                                                           | -    | -            | 10G Switch                          |
| US-16-150W         | UniFi US-16-150W         | -        | -                                                           | -    | -            | PoE Switch                          |
| UAP-AC-LR          | UniFI AC Long-Range      | -        | -                                                           | -    | -            | WiFi                                |
---

## 🤝 Thanks
Big thanks to [onedr0p](https://github.com/onedr0p) for creating [cluster-template](https://github.com/onedr0p/cluster-template) which I used as a foundation when setting up this cluster. Shout out to everyone in the [Home Operations](https://discord.gg/home-operations) Discord community for amazing conversations.

Check out [kubesearch.dev](https://kubesearch.dev/) for ideas on applications you might want to deploy to your cluster.

Thanks to [MacroPower](https://github.com/MacroPower) for allowing usage to anyone of the amazing k8spepega.
