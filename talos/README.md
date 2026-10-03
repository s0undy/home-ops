# Talos Configuration

Talos machine configuration is managed with [topf](https://github.com/postfinance/topf).

Unlike talhelper, topf does not generate machine configs into the repository — it assembles
them in memory and pushes them to the nodes over the Talos API. Use `just talos render` to
write them to `talos/output/` for inspection (gitignored), and `just talos diff` to see what
would change on the live cluster.

## Layout

| Path | Purpose |
| --- | --- |
| `topf.yaml` | Cluster name/endpoint, Talos & Kubernetes versions, schematic, node list |
| `schematic.yaml` | Image Factory schematic (system extensions); topf hashes it into a schematic ID |
| `talsecret.sops.yaml` | Talos secrets bundle, SOPS-encrypted (referenced by `secretsPath`) |
| `all/` | Patches applied to every node |
| `control-plane/` | Patches applied to control plane nodes |
| `node/${hostname}/` | Patches applied to a single node |

A `worker/` directory would hold patches for every worker node. There is one worker,
`jit-talos-04`, and everything specific to it lives in `node/jit-talos-04/` instead — it is the
dedicated GPU node (see below), so its settings are properties of that node rather than of workers
in general.

## The GPU node

`jit-talos-04` is a small (8 GB / 4 vCPU) worker that owns the Intel iGPU. Passing a PCI device to
a Proxmox VM forces Proxmox to pin the VM's entire assigned RAM, so keeping the iGPU on a 16 GB
control plane node reserved 16 GB on the host to serve one Jellyfin transcoder.

It carries the taint `gpu.intel.com/i915=true:NoSchedule` (`node/jit-talos-04/10-kube-node.yaml`)
so nothing but GPU work lands on it. Anything that legitimately has to run there needs a matching
toleration — today that is Jellyfin, the ceph-csi rbd/cephfs node plugins, the Intel GPU device
plugin, the node-feature-discovery worker and the VictoriaLogs collector. `cilium`, `spegel` and
`node-exporter` already tolerate everything. `multus` does not run there: its chart exposes no
tolerations value, and nothing on that node uses a NetworkAttachmentDefinition.

## Patch merge order

Patches merge in this order, and lexicographically by filename within each directory — hence
the numeric prefixes:

```
all/  →  control-plane/  →  node/${hostname}/
```

topf prepends a generated `machine.install.image` patch before all of the above, so a later
patch setting `machine.install.image` wins.

## Patch format

- `*.yaml` — [strategic merge patch](https://docs.siderolabs.com/talos/v1.14/talos-guides/configuration/patching)
- `*.yaml.tpl` — Go-templated strategic merge patch (sprig functions, `.Node.Host`, `.Data.*`, …)

Patches are written in the Talos v1.14 [multi-document format](https://docs.siderolabs.com/talos/v1.14/reference/configuration/document-map):
each `---`-separated document carries `apiVersion: v1alpha1` and a `kind:`. Two settings have
no multi-doc equivalent and stay in the legacy `machine:` / `cluster:` form — `machine.certSANs`
(`all/10-certsans.yaml`) and `cluster.etcd` (`control-plane/10-etcd.yaml`). Setting a field in
both forms at once is a hard validation error, so a field moves wholesale or not at all.

Talos v1.14 injects some documents at generation time that no patch asks for. Two of them are
explicitly overridden here — `KubeFlannelCNIConfig` and the `PodSecurity`
`KubeAdmissionControlConfig` are deleted with `$patch: delete`, and `SecurityProfileConfig` is
pinned to `workloadIsolation: true`. Omitting a patch is *not* the same as disabling the
feature; check `just talos render` output after changing anything here.

Two constraints worth remembering:

- **RFC 6902 JSON patches are not supported.** Use `$patch: delete` to remove a key.
  (Note: under talhelper this had to be escaped as `$$patch: delete`. It must not be escaped here.)
- **`.tpl` files are not SOPS-decrypted.** Secrets reach templates via `data:` in an encrypted
  `topf.yaml`, not from an encrypted `.tpl`.

## Extensions

`schematic.yaml` lists the system extensions. **Keep the list alphabetically sorted** — topf
hashes the file as written, and the Image Factory stores schematics with sorted extensions, so an
unsorted list produces a schematic ID the factory has never seen. Verify with:

```sh
mise exec -- topf schematic-ids   # must return a schematic the factory knows
curl -s https://factory.talos.dev/schematics/<id>
```

If you add an extension, run `topf --submit-to-factory schematic-ids` once so the factory
learns the new schematic before upgrading any node.

## Building an ISO

Needed when adding a node, or reinstalling one from scratch. There is no `just` recipe — the ISO
is built by the Image Factory from the same schematic ID the installer image uses, so a new node
never needs a schematic change.

```sh
cd talos
mise exec -- topf schematic-ids                      # e.g. 74e275aa…9294
curl -s https://factory.talos.dev/schematics/<id>    # 404 → --submit-to-factory first
```

Then, on the Proxmox host as root — the version must match `talosVersion` in `topf.yaml`:

```sh
cd /var/lib/vz/template/iso
wget -O talos-v1.14.0-metal-amd64.iso \
  https://factory.talos.dev/image/<id>/v1.14.0/metal-amd64.iso
```

Boot the new VM from it; it comes up in maintenance mode at its DHCP/static address, ready for
`just talos apply-node <host>`. Check the install disk's PCI path matches the selector in
`all/00-unattended-install.yaml` first:

```sh
mise exec -- talosctl -n <ip> --insecure get disks
```
