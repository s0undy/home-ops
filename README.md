<div align="center">

<img src="https://camo.githubusercontent.com/5b298bf6b0596795602bd771c5bddbb963e83e0f/68747470733a2f2f692e696d6775722e636f6d2f7031527a586a512e706e67" align="center" width="144px" height="144px"/>

### My homelab kubernetes repository :metal:

... managed with Flux, mended by Renovate, broken by me

</div>

<div align="center">

[![Kubernetes](https://img.shields.io/badge/v1.26.1+k3s1-blue?style=for-the-badge&logo=kubernetes&logoColor=white)](https://k3s.io/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-blue?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![GitHub last commit](https://img.shields.io/github/last-commit/s0undy/kube-ops?style=for-the-badge&logo=github)](https://github.com/s0undy/kube-ops/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/s0undy/kube-ops?style=for-the-badge&logo=github)](https://github.com/s0undy/kube-ops/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/s0undy/kube-ops?style=for-the-badge&logo=github)](https://github.com/s0undy/kube-ops/pulls)
[![GitHub repository stars](https://img.shields.io/github/stars/s0undy/kube-ops?style=for-the-badge&logo=github)](https://github.com/s0undy/kube-ops/stargazers)

</div>

## K8s Applications

While all aplications are created equal(or not), some are more important than others. Following below is a list of (all) applications currently running in the cluster.

### Core

- [Flux](https://fluxcd.io/): GitOps operator for managing a Kubernetes clusters from a Git repository.
- [Kube-VIP](https://kube-vip.io/): Load balancer for the Kubernetes control plane nodes.
- [MetalLB](https://metallb.universe.tf/): MetalLB load-balancer implementation for bare metal clusters.
- [Cert-Manager](https://cert-manager.io/): Operator issuing SSL certificates and storing them in kubernetes resources.
- [Calico](https://www.tigera.io/project-calico/): Networking and security for containers and Kubernetes services networking.
- [ExternalDNS](https://github.com/kubernetes-sigs/external-dns): Operator publishing DNS records to public DNS based on Kubernetes ingresses.
- [K8s-Gateway](https://github.com/ori-edge/k8s_gateway): DNS Resolver providing local DNS to Kubernetes ingresses.
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/): Kubernetes ingress controller used as a HTTP reverse proxy of ingresses.
- [Rook-Ceph](https://rook.io/): Distributed block storage for persistent storage.
- [SOPS](https://fluxcd.io/flux/guides/mozilla-sops/): Secret secrets for Kubernetes, Ansible and Terraform that can be commited to Git.

### Applications

In no specific order heres what's running in the cluster. ~Subject to change~

- [CloudNativePG](https://cloudnative-pg.io/): Operator covering full lifecycle of HA PostgreSQL database cluster.
- [MariaDB](https://github.com/bitnami/charts/tree/main/bitnami/mariadb): MariaDB SQL database server.
- [pgAdmin](https://www.pgadmin.org/): PostgreSQL administration and development.
- [phpMyAdmin](https://www.phpmyadmin.net/): MariaDB/MySQL administration and development.
- [Redis](https://redis.io/): In-memory data structure store. Key-value database. HA using Redis Sentinel.
- [HAProxy](https://www.haproxy.org/): Loadbalancer for HA-Redis Cluster.
- [qBittorent](https://www.qbittorrent.org/): Downloading client for Linux ISO's. :skull_and_crossbones:
- [Echo-Server](https://github.com/jmalloc/echo-server): Connection testing.
- [Hajimari](https://hajimari.io/): Simplistic dashboard with Kubernetes application discovery.
- [Weave GitOps](https://www.weave.works/product/gitops/): Dashboard for Flux GitOps
- [Nextcloud](https://nextcloud.com/): OneDrive replcement for filesharing and document editor using Collabra add-on
- [Intel-device-plugin](https://intel.github.io/intel-device-plugins-for-kubernetes/README.html#gpu-device-plugin): Provides access to Intel GPU devices.
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner): Provides a way for Kubernetes to utilize local storage of each node.
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server): Collects metrics from Kublets and exposes them in Kubernetes API-server.
- [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery): Discovery of hardware features and system configuration.
- [Reloader](https://github.com/stakater/Reloader): Watches for changes in ConfigMaps and Secrets to perform rolling uppgrades on Deployments.
- [Plex](https://www.plex.tv/): Self-Hosted Media server
- [Prowlarr](https://github.com/Prowlarr/Prowlarr): Indexer manager/proxy. :skull_and_crossbones:
- [Sonarr](https://github.com/Sonarr/Sonarr): PVR monitoring RSS feeds. :skull_and_crossbones:
- [Radarr](https://github.com/Radarr/Radarr): PVR monitoring RSS feeds. :skull_and_crossbones:
- [Goldilocks](https://github.com/FairwindsOps/goldilocks): Provides resource recommendations using VPA in Kubernetes.
- [Grafana](https://grafana.com/): Visualization for various metrics collected inside the cluster.
- [Prometheus](https://prometheus.io/): Metrics&Altering - Deployed using Kube-Prometheus-Stack.
- [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/): Basic Kubernetes interface of applications.
- [VPA](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler): Used to provide resource recommendations via Goldilocks
- [Cloudflare DDNS](https://ghcr.io/onedr0p/kubernetes-kubectl) Used together with a shell-script to update public DNS record in Cloudflare
- [MinIO](https://min.io/): Object Storage - Used to expose a NFS share as a S3 endpoint.
- [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller): Used to plan and execute upgrades of Kubernetes nodes.
- [Pod-Gateway](https://github.com/angelnu/pod-gateway): Used to route trafic from pods through another gateway. Uses [gateway admision controller](https://github.com/angelnu/gateway-admision-controller) to mutate pods.
- [Littlelink](https://github.com/techno-tim/littlelink-server): Selfhosted DIY alternative to Linktree
- [Matomo](https://matomo.org/): Self-hosted alternative to Google Analytics

## Hardware

| Device                    | Count | OS Disk Size | Data Disk Size              | Ram  | Operating System | Purpose             |
|---------------------------|-------|--------------|-----------------------------|------|------------------|---------------------|
| Lenovo ThinkCentre M710q  | 3     | 128GB SSD    | -                           | 16GB | Ubuntu 22.04     | Kubernetes Control Plane   |
| Lenovo ThinkCentre M920q  | 3     | 128GB SSD    | 1TB NVMe Crucial P3 (ceph)  | 32GB | Ubuntu 22.04     | Kubernetes Workers  |
| Synology DS412            | 1     | -            | 4x3TB SHR                   | 2GB  | DSM              | NFS                 |
| Netgear ReadyNAS 2100     | 1     | -            | 4x2TB                       | 2GB  | ReadyNAS OS6     | Backup & Testing    |
| Raspberry Pi 4            | 1     | 32GB (SD)    | -                           | 4GB  | Raspbian         | DNS-Backup          |
| UniFi Dream Machine Pro   | 1     | -            | -                           | -    | -                | Firewall/Controller |
| UniFi Switch 16-POE 150W  | 1     | -            | -                           | -    | -                | Switching           |
| UniFi UAP-AC-LR           | 1     | -            | -                           | -    | -                | Wirless Networking  |
| IKEA Tradfri Gateway      | 1     | -            | -                           | -    | -                | Smart Home          |

## 🤝 Thanks

Shoutout to [k8s@home](https://discord.gg/Yv2gzFy) and specially [onedr0p](https://github.com/onedr0p).

## TODO

Continue writing this readme to add installation guide, list of used apps, hardware and more.
