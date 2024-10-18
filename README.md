<div align="center">

<img src="https://raw.githubusercontent.com/s0undy/home-ops/main/docs/assets/k8spega.png" align="center" width="400px" height="200px"/>

### Home-ops with K8s and friends 👪
Automated with [Flux](https://fluxcd.io), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)  🤖
</div>

## 📄 Overview
Monorepo for Kubernetes cluster running in my apartment. Applying Infrastructure as Code (IaC) and GitOps as much as possible using the likes of [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Ansible](https://www.ansible.com/), [Terraform](https://www.terraform.io/) and many more awsome tools while learning on the fly.

### ⛵ Kubernetes
I run a 6 node hyper-converged (HCI) [Talos](https://www.talos.dev) cluster comprised of 3 control-plane nodes and 3 worker nodes. The only * to this that would make it semi-hypger-converged is some workloads using storage from my NAS via NFS mounts.

If you find this interesting and want to get started doing something similar i can strongly recommend taking a look at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)

### Core Components
- [Flux](https://fluxcd.io/): Gitops for Kubernetes
- [Cert-manager](https://github.com/cert-manager/cert-manager): Requests SSL certificates from [Let's Encrypt](https://letsencrypt.org/).
- [Cilium](https://github.com/cilium/cilium): eBPF-based Internal Kubernetes container networking interface.
- [Cloudflared](https://github.com/cloudflare/cloudflared): Secure access to certain ingrsses via Cloudflare.
- [External-DNS](https://github.com/kubernetes-sigs/external-dns): Automatically syncs ingress DNS records to a DNS provider.
- [Ingress-NGINX](https://github.com/kubernetes/ingress-nginx): Kubernetes ingress controller using NGINX as a reverse proxy and load balancer.
- [Rook-Ceph](https://github.com/rook/rook): Distributed block, file and S3 storage for peristent storage.
- [SOPS](https://github.com/getsops/sops): Managed secrets for Kubernetes and Terraform which are commited to Git.
- [Spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.


### Directory
The repository should look something like this. (Subject to change)

```
📁 .devcontainer        # Container containing(hehe) all tools needed to run the cluster
📁 .github           # Github workflows and Renovate config
📁 .taskfiles       # Usefull taskfiles for easy administration & setup of the cluster
📁 .vscode          # VSCode config
📁 docs             # Documentation about the repository
📁 kubernetes
└── 📁 apps           # Contains all applications and resources that flux will apply
└── 📁 bootstrap      # bootstrap procedures
└── 📁 flux           # core flux configuration
📁 scripts            # Usefull scripts
📁 terraform          # Terraform code to create resources e.g S3 buckets
```
### Short workflow
[Flux](https://fluxcd.io/) watches over cluster in my [kubernetes](https://github.com/s0undy/home-ops/tree/main/kubernetes) folder and makes changes based on the state of the repository.

Recursively searching `kubernetes/` for the most top level `kustomization.yaml` per directory and applies all the resources listed in it. The `kustomization.yaml` generally only consists of a namespace and one or many Flux kustomizations (`ks.yaml`). In the `ks.yaml` there will be references to a `HelmRelease`or other resources that will be appliced and deployed to the cluster.

[Renovate](https://github.com/renovatebot/renovate) watches over the repo looking for dependency updates, such as new versions of containers and when they are found a pull-request is automagically created in this repository. When I then merge these pull-requests ful will detect changes to the repository and apply the changes to the cluster. Magic! ✨

### Networking

#TODO

### ☁️ Dependencies
Most of my infrastructure is self-hosted, however certain parts are easier and safer to run in the cloud.

| Service                                         | Use                                                               | Cost                |
|-------------------------------------------------|-------------------------------------------------------------------|---------------------|
| [Cloudflare](https://www.cloudflare.com/)       | NS, Tunnle and S3                                                 | Free                |
| [HOSTUP](https://www.cloudflare.com/)           | Domain                                                            | 125kr/year(12$)     |
| [GitHub](https://github.com/)                   | Hosting this repository and continuous integration/deployments    | Free                |
|                                                 |                                                                   | Total: ~12kr/mo(1$) |


