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

A `worker/` directory would hold worker-only patches; there are no worker nodes in this cluster.

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
pinned to `workloadIsolation: false`. Omitting a patch is *not* the same as disabling the
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
