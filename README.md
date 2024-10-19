<div align="center">

<img src="https://raw.githubusercontent.com/s0undy/home-ops/main/docs/assets/k8spega.png" align="center" width="400px" height="200px"/>

### Home-ops with K8s and friends 👪
Automated with [Flux](https://fluxcd.io), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)  🤖
</div>

# 📄 Overview
This is a monorepo for a Kubernetes cluster running in my apartment. Applying Infrastructure as Code (IaC) and GitOps as much as possible using the likes of [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Ansible](https://www.ansible.com/), [Terraform](https://www.terraform.io/) and many more awesome tools while learning on the fly.

## ⛵ Kubernetes
I run a 6 node hyper-converged (HCI) [Talos](https://www.talos.dev) cluster comprised of 3 control-plane nodes and 3 worker nodes. The only aspect that makes it semi-hyper-converged is that some workloads use storage from my NAS via NFS mounts.

If you find this interesting and want to get started doing something similar I can strongly recommend taking a look at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)

### Core Components
- [Flux](https://fluxcd.io/): Gitops for Kubernetes
- [Cert-manager](https://github.com/cert-manager/cert-manager): Requests SSL certificates from [Let's Encrypt](https://letsencrypt.org/).
- [Cilium](https://github.com/cilium/cilium): eBPF-based Internal Kubernetes container networking interface.
- [Cloudflared](https://github.com/cloudflare/cloudflared): Secure access to certain ingresses via Cloudflare.
- [External-DNS](https://github.com/kubernetes-sigs/external-dns): Automatically syncs ingress DNS records to a DNS provider.
- [Ingress-NGINX](https://github.com/kubernetes/ingress-nginx): Kubernetes ingress controller using NGINX as a reverse proxy and load balancer.
- [Rook-Ceph](https://github.com/rook/rook): Distributed block, file and S3 storage for persistent storage.
- [SOPS](https://github.com/getsops/sops): Managed secrets for Kubernetes and Terraform which are committed to Git.
- [Spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.


### Directory
The repository should look something like this. (Subject to change)

```
📁 .devcontainer        # Container containing(hehe) all tools needed to run the cluster
📁 .github           # Github workflows and Renovate config
📁 .taskfiles       # Useful taskfiles for easy administration & setup of the cluster
📁 .vscode          # VSCode config
📁 docs             # Documentation about the repository
📁 kubernetes
└── 📁 apps           # Contains all applications and resources that flux will apply
└── 📁 bootstrap      # bootstrap procedures
└── 📁 flux           # core flux configuration
📁 scripts            # Useful scripts
📁 terraform          # Terraform code to create resources e.g S3 buckets
```
### Short workflow
[Flux](https://fluxcd.io/) watches over cluster in my [kubernetes](https://github.com/s0undy/home-ops/tree/main/kubernetes) folder and makes changes based on the state of the repository.

Flux recursively searches the `kubernetes/` directory for the most top level `kustomization.yaml` per directory and applies all the resources listed in it. The `kustomization.yaml` generally only consists of a namespace and one or many Flux kustomizations (`ks.yaml`). The `ks.yaml` will reference a HelmRelease or other resources that will be applied and deployed to the cluster.

[Renovate](https://github.com/renovatebot/renovate) watches over the repo looking for dependency updates, such as new versions of containers and when they are found a pull-request is automagically created in this repository. When I merge these pull-requests, Flux will detect changes to the repository and apply them to the cluster. Magic! ✨

## Network
<details>
  <summary>Click to view the network topology</summary>

  <img src="https://raw.githubusercontent.com/s0undy/home-ops/main/docs/assets/networktopology.png" align="center"/>
</details>

## 🌐 DNS

### Cluster/Public
In the cluster, I run [ExternalDNS](https://github.com/kubernetes-sigs/external-dns), which creates DNS records in Cloudflare to publish ingresses that has the class name of `external` and the annotation `external-dns.alpha.kubernetes.io/target`.

### Home DNS
Devices on the LAN use Pi-hole, hosted on my UDM-Pro in an nspawn-container, as their DNS. Pi-hole uses the in-cluster external-dns as a conditional forwarder for my domain, allowing me to access resources published from the cluster.

In the future I plan to transition to using UniFi as DNS server on my UDM-Pro and use [ExternalDNS webhook provider for UniFi](https://github.com/kashalls/external-dns-unifi-webhook) to automagically create DNS records.


## ☁️ Dependencies
Most of my infrastructure is self-hosted, however certain parts are easier and safer to run in the cloud.

| Service                                         | Use                                                               | Cost                |
|-------------------------------------------------|-------------------------------------------------------------------|---------------------|
| [Cloudflare](https://www.cloudflare.com/)       | NS, Cloudflare tunnel and S3                                      | Free                |
| [HOSTUP](https://www.cloudflare.com/)           | Domain                                                            | 125kr/year(12$)     |
| [GitHub](https://github.com/)                   | Hosting this repository and continuous integration/deployments    | Free                |
|                                                 |                                                                   | Total: ~12kr/mo(1$) |
---

## 🔧 Hardware
| Name               | Device                   | CPU      | OS Disk      | Data Disk     | RAM  | OS    | Purpose                             |
|------------------------|--------------------------|----------|--------------|---------------|------|-------|-------------------------------------|
| JIT-M1                 | Lenovo ThinkCentre M910q | i5-7500T | 240GB NVMe   | -             | 16GB | Talos | control-plane                       |
| JIT-M2                 | Lenovo ThinkCentre M910q | i7-7500T | 240GB NVMe   | -             | 16GB | Talos | control-plane                       |
| JIT-M3                 | Lenovo ThinkCentre M900  | i5-6500T | 240GB NVMe   | -             | 16GB | Talos | control-plane                       |
| JIT-W1                 | Lenovo ThinkCentre M920q | i5-8500T | 256GB SSD    | 1TB NVME      | 32GB | Talos | worker                              |
| JIT-W2                 | Lenovo ThinkCentre M720q | i5-9500T | 256GB SSD    | 1TB NVME      | 32GB | Talos | worker                              |
| JIT-W3                 | Lenovo ThinkCentre M720q | i5-9500T | 240GB SSD    | 1TB NVME      | 32GB | Talos | worker                              |
| DS412                  | Synology DS412+          | -        | -            | 4x4TB WD-Red  | -    | DSM   | NAS, NFS for media  e.tc            |
| Octo                   | Raspberry 4 Model B      | -        | 64GB SD-card | -             | 4GB  | Pi OS | OctoPi for my Ender 5 S1 3D-Printer |
| UDM-1                  | UniFi Dream Machine Pro  | -        | -            | -             | -    | -     | Router, Firewall and future DNS     |
| US-16-150W-Switch      | UniFi Switch US-16-150W  | -        | -            | -             | -    | -     | Switch+POE                          |
| UAP-AC-LR-Acces Point  | UniFI AC Long-Range      | -        | -            | -             | -    | -     | WiFi                                |
---

## 🤝 Thanks
Big thanks to [onedr0p](https://github.com/onedr0p) for creating [cluster-template](https://github.com/onedr0p/cluster-template) which I used as a foundation when learning Kubernetes and setting up my cluster. Shout out to everyone in the [Home Operations](https://discord.gg/home-operations) Discord community for amazing conversations and always helping out.

Check out [kubesearch.dev](https://kubesearch.dev/) for ideas on applications you might want to deploy to your cluster

Thanks to [MacroPower](https://github.com/MacroPower) for allowing usage to anyone of the amazing k8spepega.
