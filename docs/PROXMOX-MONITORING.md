# 📊 Proxmox host monitoring

Node-level metrics for the three physical Proxmox hosts — **arx**, **pax** and **via** — covering
CPU temperature, host filesystems, and SMART / NVMe disk health.

This is the one part of the monitoring stack that is **not** GitOps-managed. Everything in
`kubernetes/` targets the cluster; the exporters described here run on the hypervisors themselves
and are installed by hand, once per host.

## 📋 Table of Contents

- [What this covers](#-what-this-covers)
- [Install](#-install)
- [Verify on the host](#-verify-on-the-host)
- [Verify in the cluster](#-verify-in-the-cluster)
- [Optional tweaks](#️-optional-tweaks)
- [Troubleshooting](#-troubleshooting)

## 🔍 What this covers

The in-cluster `node-exporter` (part of kube-prometheus-stack) monitors the **Talos VMs** at
`10.0.100.11-13`. It knows nothing about the hardware underneath them. This adds a second
node_exporter on the **physical hosts** at `172.16.24.11-13`, scraped as job `proxmox-node`.

📍 _The two jobs are deliberately named differently. Every expression in the chart's stock
node-exporter alert rules matches `job="node-exporter"`; reusing that name would silently point
the VM alerts at the hypervisors as well._

| Source | Metrics |
| --- | --- |
| node_exporter core collectors | CPU, memory, load, network, disk I/O, host filesystems |
| node_exporter `hwmon` collector | `node_hwmon_temp_celsius` — CPU package and NVMe temperatures |
| node_exporter `systemd` collector | `node_systemd_unit_state` — handy for `ceph-osd@*`, `pvestatd` |
| `smartmon.sh` textfile collector | `smartmon_*` for the SATA SSD (the PVE boot disk) |
| `nvme_metrics.py` textfile collector | `nvme_*` for the NVMe drives — endurance, media errors, spare, temperature |

The repo side (ScrapeConfig, alert rules, dashboards) lives in
[kubernetes/apps/o11y/kube-prometheus-stack/app/](../kubernetes/apps/o11y/kube-prometheus-stack/app/)
and [kubernetes/apps/o11y/grafana-operator/instance/grafanadashboard.yaml](../kubernetes/apps/o11y/grafana-operator/instance/grafanadashboard.yaml).

## 📦 Install

Proxmox VE 9 is built on Debian 13 (trixie), which carries everything needed in its base
repositories — no backports and no third-party APT sources.

Run as root on **each** of arx, pax and via:

1. Install the exporter, the collector scripts, and the tools they shell out to:

    ```sh
    apt update
    apt install --no-install-recommends \
      prometheus-node-exporter prometheus-node-exporter-collectors \
      smartmontools nvme-cli moreutils
    ```

    📍 _`moreutils` provides `sponge`, which both collector units pipe their output through.
    `smartmontools` and `nvme-cli` gate the two timers via `ConditionFileIsExecutable` — without
    them the timers are installed but never fire._

2. Enable the exporter and the two collector timers:

    ```sh
    systemctl enable --now prometheus-node-exporter.service
    systemctl enable --now prometheus-node-exporter-smartmon.timer
    systemctl enable --now prometheus-node-exporter-nvme.timer
    ```

> [!TIP]
> No configuration file needs editing. Debian patches node_exporter's built-in default for
> `--collector.textfile.directory` to `/var/lib/prometheus/node-exporter`, which is exactly where
> both collector units write, so the shipped `ARGS=""` in
> `/etc/default/prometheus-node-exporter` is correct as-is.

> [!NOTE]
> The timers run every 15 minutes but also fire at `OnBootSec=0`, so the first `.prom` files
> appear within a few seconds of enabling them — no need to wait out a cycle.

## ✅ Verify on the host

```sh
systemctl list-timers 'prometheus-node-exporter-*'
ls -l /var/lib/prometheus/node-exporter/    # expect smartmon.prom and nvme.prom

curl -s localhost:9100/metrics | grep -c '^node_hwmon_temp_celsius'   # > 0
curl -s localhost:9100/metrics | grep -c '^nvme_'                     # > 0
curl -s localhost:9100/metrics | grep -c '^smartmon_'                 # > 0
```

## 🔗 Verify in the cluster

```sh
kubectl run -n o11y netcheck --rm -it --restart=Never --image=docker.io/alpine/curl:latest -- \
  sh -c 'for i in 11 12 13; do curl -s -o /dev/null -w "$i %{http_code}\n" \
    http://172.16.24.$i:9100/metrics; done'
```

Three `200`s. Then in Prometheus (`https://prometheus.${SECRET_DOMAIN}` → Status → Targets) the
`proxmox-node` job should show three UP targets, and these should each return three or more
series:

```promql
count(node_uname_info{job="proxmox-node"})
count(node_hwmon_temp_celsius{job="proxmox-node"})
count(nvme_percentage_used_ratio)
count(smartmon_device_smart_healthy)
```

In Grafana, the **Proxmox** folder holds *Node Exporter Full*, *S.M.A.R.T disk monitoring* and
*NVMe health*.

## 🎛️ Optional tweaks

Both go in `ARGS` in `/etc/default/prometheus-node-exporter`, followed by
`systemctl restart prometheus-node-exporter`.

**Include PVE storage mounts.** Debian's packaging excludes `/mnt` and `/media` from the
filesystem collector, so anything mounted under `/mnt/pve/*` is not graphed. To restore upstream
behaviour for those paths:

```sh
ARGS="--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)"
```

**Restrict the listen address.** node_exporter binds `:9100` on every interface, including the
Ceph storage network. To expose it on the management address only (substitute each host's own IP):

```sh
ARGS="--web.listen-address=172.16.24.11:9100"
```

## 🐛 Troubleshooting

**No `node_hwmon_temp_celsius` series.** The `coretemp` module has not loaded:

```sh
apt install lm-sensors
sensors-detect --auto
systemctl restart prometheus-node-exporter
```

**No `smartmon_*` series.** The smartmon unit is gated on `ConditionPathExistsGlob=|/dev/sd*`, so
it only runs where a SATA or SCSI disk exists — NVMe-only hosts get nothing from it by design, and
their disks are covered by `nvme_*` instead. Otherwise check the run:

```sh
systemctl start prometheus-node-exporter-smartmon.service
systemctl status prometheus-node-exporter-smartmon.service
```

**No `nvme_*` series.** Same check against `prometheus-node-exporter-nvme.service`. It needs
`/usr/sbin/nvme` present, i.e. the `nvme-cli` package.

**Targets DOWN in Prometheus but `curl localhost:9100` works on the host.** Either the PVE
firewall is filtering 9100, or `--web.listen-address` was narrowed to an address the cluster
cannot reach. Port 8006 is already reachable from pods (the `proxmox` job scrapes the PVE API),
so routing between the cluster and `172.16.24.0/24` is not the problem.
