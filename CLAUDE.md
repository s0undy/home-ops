# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A GitOps monorepo for a self-hosted 3-node Talos Kubernetes cluster running on Proxmox. There is no build or test suite — Flux watches the `kubernetes/` directory and applies whatever is committed to `main`. Changes take effect by merging to `main` (or `just kube reconcile` to force an immediate sync). Renovate opens PRs for dependency updates.

## Tooling and commands

CLI tools are pinned and installed with [mise](https://mise.jdx.dev) (`mise trust && mise install`). `.mise.toml` also sets the required env vars: `KUBECONFIG`, `TALOSCONFIG`, `SOPS_AGE_KEY_FILE` (age key at `./age.key`), and `JUST_UNSTABLE=1`.

**Important:** mise activates these tools per-directory, so `kubectl`, `talosctl`, `flux`, `sops`, `cilium`, `helm`, etc. are only on PATH when the working directory is the repo root (`~/k8s/home-ops`). Run all commands from there — in non-interactive shells where mise isn't activated, prefix commands with `mise exec --` (e.g. `mise exec -- kubectl get pods`).

Task runner is `just` (recipes in `.justfile`, modules in `*/mod.just`):

- `just kube reconcile` — force Flux to pull in Git changes
- `just talos generate-config` — regenerate Talos machine configs with talhelper after editing `talos/talconfig.yaml`
- `just talos apply-node <ip>` — apply Talos config to a node
- `just talos upgrade-node <ip>` / `just talos upgrade-k8s` — upgrade Talos/Kubernetes to the versions pinned in `talos/talenv.yaml`
- `just bootstrap talos` / `just bootstrap apps` — full cluster bootstrap from scratch (see `docs/BOOTSTRAP.md`)

Validate manifests locally with `kustomize build <dir>` and `kubeconform` (both installed via mise). Debugging flow: `flux get ks -A`, `flux get hr -A`, then `kubectl -n <ns> describe`/`logs` (see the Debugging section of `docs/BOOTSTRAP.md`).

## Architecture

### Flux structure

The entry point is `kubernetes/flux/cluster/ks.yaml`: a `cluster-apps` Flux Kustomization that applies `kubernetes/apps/` and patches **defaults into every child Kustomization** — SOPS decryption, and HelmRelease install/upgrade remediation settings. Don't repeat those settings in per-app manifests.

Every app follows the same three-level pattern:

```
kubernetes/apps/<namespace>/            # one directory per namespace
├── kustomization.yaml                  # namespace.yaml + each app's ks.yaml + sops component
├── namespace.yaml
└── <app>/
    ├── ks.yaml                         # Flux Kustomization pointing at ./app
    └── app/
        ├── kustomization.yaml
        ├── helmrelease.yaml
        └── ocirepository.yaml          # chart source (OCI)
```

- The namespace-level `kustomization.yaml` includes the `../../components/sops` component, which provides the `cluster-secrets` Secret to the namespace.
- App `ks.yaml` files use `postBuild.substituteFrom: cluster-secrets`, so manifests can reference variables like `${SECRET_DOMAIN}`.
- Most workloads use the bjw-s `app-template` Helm chart via an `OCIRepository`; `kubernetes/apps/default/echo` is the reference example.
- HTTPRoutes attach to the Envoy Gateway parentRefs `envoy-external` or `envoy-internal` in the `network` namespace; external-dns creates DNS records accordingly (Cloudflare for external, UniFi/UDM Pro for internal).

### Secrets

SOPS + age, rules in `.sops.yaml`. Secret files are named `*.sops.yaml`; under `kubernetes/` and `bootstrap/` only `data`/`stringData` fields are encrypted. Edit with `sops edit <file>`. Never commit an unencrypted secret, and never touch `*.sops.*` files with plain editing tools — encrypted values are MAC-protected.

### Storage and infra specifics

- Rook-Ceph runs in **external mode** — the Ceph cluster lives on the Proxmox hosts, not in Kubernetes (`kubernetes/apps/rook-ceph/`, import scripts in `scripts/`).
- CloudNativePG provides Postgres (`kubernetes/apps/databases/`), backed up via Barman Cloud.
- Talos node config is managed by talhelper: `talos/talconfig.yaml` (nodes/patches) and `talos/talenv.yaml` (version pins); generated output in `talos/clusterconfig/` .
- `bootstrap/helmfile.d/` contains the ordered CRD + core-app installs (Cilium, CoreDNS, Spegel, flux-operator) used only during initial bootstrap.
