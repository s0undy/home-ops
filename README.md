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
[![GitHub repository lines](https://img.shields.io/tokei/lines/github/s0undy/kube-ops?style=for-the-badge&logo=github)](https://github.com/s0undy/kube-ops/graphs/contributors)

</div>

## Hardware
| Device                    | Count | OS Disk Size | Data Disk Size              | Ram  | Operating System | Purpose             |
|---------------------------|-------|--------------|-----------------------------|------|------------------|---------------------|
| Lenovo ThinkCentre M710q  | 3     | 128GB SSD    | -                           | 16GB | Ubuntu 22.04     | K8S Control Plane   |
| Lenovo ThinkCentre M920q  | 3     | 128GB SSD    | 1TB NVMe Crucial P3 (ceph)  | 32GB | Ubuntu           | Kubernetes Workers  |
| Synology DS412            | 1     | -            | 4x3TB SHR                   | 2GB  | DSM              | NFS                 |
| Netgear ReadyNAS 2100     | 1     | -            | 4x2TB                       | 2GB  | ReadyNAS OS6     | Backup & Testing    |
| Raspberry Pi 4            | 1     | 32GB(SD)     | -                           | 4GB  | Raspbian         | DNS-Backup          |
| UniFi Dream Machine Pro   | 1     | -            | -                           | -    | -                | Firewall/Controller |
| UniFi Switch 16-POE 150W  | 1     | -            | -                           | -    | -                | Switching           |
| UniFi UAP-AC-LR           | 1     | -            | -                           | -    | -                | Wirless Networking  |
## 🤝 Thanks
Shoutout to [k8s@home](https://discord.gg/Yv2gzFy) and specially [onedr0p](https://github.com/onedr0p) for creating [flux-cluster-template](https://github.com/onedr0p/flux-cluster-template) to enable a "simple" way for anyone to get going with k8s.
## TODO
Continue writing this readme to add installation guide, list of used apps, hardware and more.
