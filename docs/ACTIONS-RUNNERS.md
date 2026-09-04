# 🏃 Self-hosted GitHub Actions runners

Ephemeral, autoscaling GitHub Actions runners for **s0undy/home-ops**, running on the cluster via
[actions-runner-controller](https://github.com/actions/actions-runner-controller) (ARC).

Manifests live in [`kubernetes/apps/actions-runner-system/`](../kubernetes/apps/actions-runner-system).
Workflows opt in with `runs-on: home-ops-runner`.

## 📋 Table of Contents

- [How it works](#-how-it-works)
- [Create the GitHub App](#-create-the-github-app)
- [Fill in the secret](#-fill-in-the-secret)
- [Verify](#-verify)
- [Constraints](#-constraints)
- [Troubleshooting](#-troubleshooting)

## 🔍 How it works

Two Flux Kustomizations, both defined in
[`actions-runner-controller/ks.yaml`](../kubernetes/apps/actions-runner-system/actions-runner-controller/ks.yaml):

| Kustomization | Path | Chart |
| --- | --- | --- |
| `actions-runner-controller` | `app/` | `gha-runner-scale-set-controller` |
| `actions-runner-controller-runners` | `runners/` | `gha-runner-scale-set` |

The controller Kustomization uses `wait: true` because the scale set needs the `AutoscalingRunnerSet`
CRD it installs; the runners Kustomization `dependsOn` it and uses `wait: false`, since a scale set
parked at `minRunners: 0` never reports Ready.

A long-lived **listener** pod polls GitHub for queued jobs. When one arrives it scales the set up,
a **runner** pod starts, and — in `containerMode: kubernetes` — the runner's container hooks create a
separate pod per workflow step. Everything is torn down when the job finishes. Idle cost is one
listener pod.

## 🔐 Create the GitHub App

ARC authenticates as a GitHub App rather than a PAT, so credentials are scoped and revocable.

1. <https://github.com/settings/apps> → **New GitHub App**. Name it e.g. `s0undy-home-ops-arc`.
   **Uncheck Webhook → Active** — ARC polls, it does not receive webhooks.
2. Repository permissions:
   - **Administration**: Read and write — required, this is what registers and removes runners
   - **Metadata**: Read-only
   - **Actions**: Read-only
3. Create the App and note the **App ID**, then **Generate a private key** (downloads a `.pem`).
4. **Install App** → select **Only select repositories** → `s0undy/home-ops`. The resulting URL ends
   in `/settings/installations/<installation_id>` — note that number.

## 🔑 Fill in the secret

[`runners/home-ops/secret.sops.yaml`](../kubernetes/apps/actions-runner-system/actions-runner-controller/runners/home-ops/secret.sops.yaml)
ships with placeholder values. Replace them from the repo root:

```sh
sops edit kubernetes/apps/actions-runner-system/actions-runner-controller/runners/home-ops/secret.sops.yaml
```

The three key names are mandated by the chart — do not rename them:

```yaml
stringData:
  github_app_id: "1234567"
  github_app_installation_id: "89012345"
  github_app_private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...paste the whole .pem, including both delimiter lines...
    -----END RSA PRIVATE KEY-----
```

Delete the downloaded `.pem` afterwards. Until this is filled in, the listener pod will CrashLoop —
the rest of the deployment is unaffected.

## ✅ Verify

```sh
just kube reconcile
flux get ks -A | grep actions-runner
kubectl -n actions-runner-system get pods
```

Expect `actions-runner-controller-…` and `home-ops-runner-…-listener` both `Running`. A healthy
listener is proof the GitHub App credentials work. Confirm from GitHub's side:

```sh
gh api repos/s0undy/home-ops/actions/runners --jq '.runners[].name'
```

End to end, using the bundled smoke test:

```sh
gh workflow run runner-smoke-test.yaml
kubectl -n actions-runner-system get pods -w   # a runner appears, then disappears
gh run watch
```

## ⚠️ Constraints

- **No Docker.** `containerMode: kubernetes` runs each step as its own pod, with no Docker daemon,
  so `docker build`/`docker run` and container-based actions will not work. Adding a second,
  dind-mode scale set alongside this one is the fix if that is ever needed.
- **`maxRunners: 2`**, with modest resource requests. The three nodes are 6 CPU / ~15Gi and already
  fairly committed; raising this means checking headroom first.
- **The work volume is `cephfs` (RWX), not `ceph-rbd`.** In kubernetes mode the runner pod and every
  workflow job pod mount the same volume, and nothing pins the job pod to the runner's node — RWO
  `ceph-rbd` would fail to multi-attach.
- **Runners cannot reach the LAN.** A `CiliumNetworkPolicy` denies egress to RFC1918 except the pod
  and service CIDRs, keeping workflow code away from the Talos API, Proxmox, and TrueNAS on
  `10.0.100.0/24`. Internet egress to GitHub is unaffected. Widen
  [`networkpolicy.yaml`](../kubernetes/apps/actions-runner-system/actions-runner-controller/runners/home-ops/networkpolicy.yaml)
  deliberately if a workflow legitimately needs an in-cluster or LAN endpoint.
- **Runner RBAC is namespace-scoped.** The chart auto-creates a ServiceAccount with just the
  pods/exec/log/jobs/secrets permissions the container hooks need. Nothing here is `cluster-admin`.

## 🔧 Troubleshooting

**Listener CrashLoops** — almost always the App credentials.

```sh
kubectl -n actions-runner-system logs -l app.kubernetes.io/component=runner-scale-set-listener
```

`401`/`404` means a wrong App ID, installation ID, or a key that does not belong to that App.
`403` usually means the **Administration: Read and write** permission is missing, or was added after
installation and the install has not been refreshed (GitHub prompts to accept new permissions).

**Job queues forever** — check that `runs-on` matches the scale set name (`home-ops-runner`, taken
from the HelmRelease name) and that the listener is `Running`.

**Job pod fails immediately** — if the error mentions a missing job container, verify
`ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER=false` is still set in the runner container's env; kubernetes
mode otherwise rejects every job that does not declare its own `container:`.

**Runner pod stuck `Pending`** — usually the cephfs work PVC.

```sh
kubectl -n actions-runner-system describe pod <runner-pod>
kubectl -n actions-runner-system get pvc
```
