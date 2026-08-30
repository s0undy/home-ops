# 💾 TrueNAS monitoring

Metrics for the TrueNAS SCALE NAS — **jit-horrea** — covering pool health and capacity,
disk temperatures, ARC, and host CPU / memory / network.

Unlike [Proxmox host monitoring](PROXMOX-MONITORING.md), nothing is installed on the NAS. TrueNAS
is an appliance with an immutable root filesystem, so this uses **SNMP**, the one supported pull
interface it exposes. The only host-side step is enabling the built-in SNMP service.

## 📋 Table of Contents

- [Why SNMP](#-why-snmp)
- [What this covers](#-what-this-covers)
- [Enable SNMP on the NAS](#-enable-snmp-on-the-nas)
- [Verify](#-verify)
- [Regenerating the exporter config](#-regenerating-the-exporter-config)
- [Known gaps](#-known-gaps)
- [Troubleshooting](#-troubleshooting)

## 🔍 Why SNMP

TrueNAS has no Prometheus endpoint, and there is no path to one:

- The middleware renders `/etc/netdata/netdata.conf` with `[web] enabled = no`, bound to
  `127.0.0.1:6999`. The netdata API is not reachable from the LAN on any version, and the UI was
  removed outright in 25.04.
- `reporting.exporters` accepts exactly one exporter type, `GRAPHITE` — still true in the
  TrueNAS 27 API models.

That rules out scraping netdata directly. The community bridge
[`truenas-graphite-to-prometheus`](https://github.com/Supporterino/truenas-graphite-to-prometheus)
converts the Graphite stream, but it requires overwriting a netdata config that middleware
regenerates on every boot, its disk-temperature mapping has been broken on 25.10 since the disk
health rework (issue #125, closed unfixed), and the built-in pool collector only emits GUID-keyed
byte counts — so pool *health* is structurally unavailable through it.

SNMP is a first-party TrueNAS service. `TRUENAS-MIB` reports pool health by name, and nothing
needs re-applying after a TrueNAS update.

## 📊 What this covers

`snmp-exporter` runs in-cluster as a scrape proxy — the NAS goes in as the `?target=` parameter,
exactly like `pve-exporter` does for Proxmox. Prometheus scrapes it as job `truenas`.

| Source | Metrics |
| --- | --- |
| `TRUENAS-MIB` zpoolTable | `zpoolHealthStatus` (0 = ONLINE), pool read/write ops and bytes |
| `TRUENAS-MIB` datasetTable | `datasetUsedBytes` / `datasetAvailableBytes` for all 52 datasets |
| `TRUENAS-MIB` hddTempTable | `hddTempValue` — per-disk temperature in milli-Celsius |
| `TRUENAS-MIB` arc / l2arc | ARC size, hits, misses, hit ratio; L2ARC hits, misses, size |
| HOST-RESOURCES-MIB | `hrStorageUsed` / `hrStorageSize` per mounted filesystem, uptime, process count |
| UCD-SNMP-MIB | CPU user/system/idle, real and swap memory, load average |
| IF-MIB | Per-interface throughput, errors, discards, link state |

Everything on the repo side lives in
[kubernetes/apps/o11y/snmp-exporter/](../kubernetes/apps/o11y/snmp-exporter/).

📍 _`zpoolHealth` is a `DisplayString` in the MIB ("ONLINE", "DEGRADED", …), which Prometheus
cannot store. The generator maps it to a numeric `zpoolHealthStatus`: 0 ONLINE, 1 DEGRADED,
2 FAULTED, 3 OFFLINE, 4 UNAVAIL, 5 REMOVED, 6 unrecognised. Alert on `!= 0`._

## 🔌 Enable SNMP on the NAS

In the TrueNAS UI, **System Settings → Services → SNMP**:

1. Set **Community** to the string stored in
   [the app's sops secret](../kubernetes/apps/o11y/snmp-exporter/app/secret.sops.yaml). Read it
   with:

    ```sh
    sops --decrypt kubernetes/apps/o11y/snmp-exporter/app/secret.sops.yaml \
      | yq '.stringData."auth.yml"'
    ```

2. Leave **SNMP v3** off — the exporter is configured for v2c on the trusted LAN.
3. Tick **Start Automatically**, then start the service.

> [!IMPORTANT]
> The community string is a credential. If you change it in the UI, change it in the secret too
> (`sops edit`) — the exporter will not start if its config has no `auths` block, and will scrape
> nothing if the community does not match.

## ✅ Verify

The NAS answers SNMP:

```sh
kubectl run -n o11y snmpcheck --rm -it --restart=Never \
  --image=quay.io/prometheus/snmp-exporter:v0.30.1 --command -- \
  wget -qO- "http://snmp-exporter.o11y.svc.cluster.local:9116/snmp?module=truenas&auth=truenas_v2&target=172.16.32.10"
```

Expect a block of metrics. A `500` means the walk failed — see Troubleshooting.

Then in Prometheus (`https://prometheus.${SECRET_DOMAIN}` → Status → Targets) the `truenas` job
should show one UP target, and each of these should return series:

```promql
count(zpoolHealthStatus{job="truenas"})
count(hddTempValue{job="truenas"})
count(datasetAvailableBytes{job="truenas"})
count(zfsArcSize{job="truenas"})
```

In Grafana, the **TrueNAS** folder holds the *TrueNAS* dashboard. Under Alerts, the `truenas`
rule group should be loaded and inactive.

## 🔄 Regenerating the exporter config

[`kubernetes/apps/o11y/snmp-exporter/app/config/snmp.yml`](../kubernetes/apps/o11y/snmp-exporter/app/config/snmp.yml)
is generated — never edit it by hand. The inputs are
[`scripts/truenas-snmp/generator.yml`](../scripts/truenas-snmp/generator.yml) and the vendored
`TRUENAS-MIB.txt` beside it.

```sh
./scripts/truenas-snmp/generate.sh
```

It downloads the IETF/net-snmp dependency MIBs (those are not vendored — they never change) and
runs the upstream generator in a container, preferring docker or podman and falling back to a
throwaway pod on the cluster. Commit `generator.yml` and the regenerated `snmp.yml` together.

After a TrueNAS upgrade, refresh the vendored MIB first — it gains objects between releases.
The vendored copy is pinned to the tag matching the running version (`TS-25.10.4`); `datasetTable`,
for instance, only appeared in 25.10.3.1, and `zvolTable` is empty on this NAS because it has no
zvols, so dataset capacity has to come from the former:

```sh
scp root@172.16.32.10:/usr/local/share/snmp/mibs/TRUENAS-MIB.txt scripts/truenas-snmp/mibs/
./scripts/truenas-snmp/generate.sh
```

> [!NOTE]
> The generated `snmp.yml` deliberately contains no `auths` block — the community string comes
> from the sops-encrypted `auth.yml`, loaded as a second `--config.file`. snmp_exporter merges
> `auths` and `modules` across config files.

## 🕳️ Known gaps

SNMP cannot report two things, because TrueNAS does not expose them over SNMP at all:

| Gap | Where to look instead |
| --- | --- |
| **SMART attributes** (reallocated / pending sectors) | TrueNAS runs its own scheduled SMART tests and raises alerts on failure — keep email alerts on under **System Settings → Alert Settings**. Disk *temperatures* are covered here. |
| **Scrub / resilver status** | Same — TrueNAS alerts on scrub failure. Scrub progress is not exported. |

Closing either one properly means running an exporter on the NAS itself. The realistic route is a
systemd-sysext on the data pool (squashfs merged into `/usr`, re-merged by a PREINIT script so it
survives updates that wipe `/usr`), carrying `smartctl_exporter` for SMART and `zfs_exporter` for
scrub state. That trades this setup's main virtue — nothing installed, nothing to re-apply — for
the extra coverage, so it was left out deliberately rather than overlooked.

## 🐛 Troubleshooting

**Exporter pod is not starting.** Check that the Secret decrypted:

```sh
kubectl -n o11y logs deploy/snmp-exporter
```

`Configuration is missing Auths.` means only `snmp.yml` was loaded — the `snmp-exporter-auth`
Secret is missing or empty.

**`500` from the exporter, `request timeout` in its logs.** The NAS is not answering on
`161/udp`. Either the SNMP service is off, or the community string does not match. The exporter
cannot tell those apart — SNMP v2c does not respond at all to a bad community.

**Target is UP but pool metrics are missing.** Confirm the MIB objects exist on the running
version; `zpoolTable` has been stable for years, but check with:

```sh
kubectl -n o11y exec deploy/snmp-exporter -- \
  wget -qO- "http://127.0.0.1:9116/snmp?module=truenas&auth=truenas_v2&target=172.16.32.10" \
  | grep zpool
```

**Cluster cannot reach the NAS.** The ScrapeConfig targets the management address
`172.16.32.10`, which is the only one that answers — SNMP does not respond on the storage address
`172.16.60.10` even though that is the one pods use for NFS. If the management VLAN ever stops
being routable from the cluster, bind SNMP to the storage interface as well before retargeting
[the ScrapeConfig](../kubernetes/apps/o11y/snmp-exporter/app/scrapeconfig.yaml) and the dashboard's
`host` variable.

**A dataset or pool disappeared from the dashboard.** Table indexes are positional and not stable
across reboots, which is why every metric is looked up to a name label (`datasetDescr`,
`zpoolName`, `hddTempDevice`) rather than an index. If a name changed on the NAS, the old series
simply stops — that is expected, not a scrape failure.
