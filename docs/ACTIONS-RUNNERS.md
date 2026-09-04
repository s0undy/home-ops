# 🏃 Self-hosted GitHub Actions runners

Ephemeral, autoscaling GitHub Actions runners running on the cluster via
[actions-runner-controller](https://github.com/actions/actions-runner-controller) (ARC).

Manifests live in [`kubernetes/apps/actions-runner-system/`](../kubernetes/apps/actions-runner-system).
One scale set per repo; workflows opt in with `runs-on:`.

| Repo | Scale set / `runs-on` | Manifests |
| --- | --- | --- |
| `s0undy/home-ops` | `home-ops-runner` | `runners/home-ops/` |
| `s0undy/ShareViewer` | `shareviewer-runner` | `runners/shareviewer/` |
| `s0undy/ShareViewer` | `shareviewer-runner-dind` | `runners/shareviewer-dind/` |

All three authenticate as the **same GitHub App**, whose one installation on the `s0undy` account
covers both repos — so they share a single `github-app-secret`, defined once at `runners/` level.

## 📋 Table of Contents

- [How it works](#-how-it-works)
- [Create the GitHub App](#-create-the-github-app)
- [Fill in the secret](#-fill-in-the-secret)
- [Verify](#-verify)
- [Add another scale set](#-add-another-scale-set)
- [Docker builds](#-docker-builds)
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
4. **Install App** → select **Only select repositories** → pick every repo that should get runners
   (currently `s0undy/home-ops` and `s0undy/ShareViewer`). The resulting URL ends in
   `/settings/installations/<installation_id>` — note that number.

Adding a repo later is just editing that repository list. It stays **one** installation, so the app
id, installation id and private key never change and no new secret is needed.

## 🔑 Fill in the secret

[`runners/github-app-secret.sops.yaml`](../kubernetes/apps/actions-runner-system/actions-runner-controller/runners/github-app-secret.sops.yaml)
holds the credentials shared by every scale set. Edit it from the repo root:

```sh
sops edit kubernetes/apps/actions-runner-system/actions-runner-controller/runners/github-app-secret.sops.yaml
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

**Keep the quotes on both IDs.** Unquoted, sops encrypts them as `type:int`, and Flux then hands
integers to a `stringData` field that only takes strings — server-side apply fails the whole
Kustomization with `expected string, got 4832057`. To repair one without an editor:

```sh
sops set <file> '["stringData"]["github_app_id"]' '"4832057"'
```

Delete the downloaded `.pem` afterwards. Until this is filled in, the listener pod will CrashLoop —
the rest of the deployment is unaffected.

## ✅ Verify

```sh
just kube reconcile
flux get ks -A | grep actions-runner
kubectl -n actions-runner-system get pods
```

Expect `actions-runner-controller-…` plus one `…-listener` per scale set, all `Running`. A healthy
listener is proof the GitHub App credentials work for that repo. Confirm from GitHub's side:

```sh
gh api repos/s0undy/home-ops/actions/runners --jq '.runners[].name'
gh api repos/s0undy/ShareViewer/actions/runners --jq '.runners[].name'
```

End to end, using the bundled smoke test:

```sh
gh workflow run runner-smoke-test.yaml
kubectl -n actions-runner-system get pods -w   # a runner appears, then disappears
gh run watch
```

## ➕ Add another scale set

Adding a repo takes one GitHub click and one directory.

1. On the GitHub App's installation, add the repo to **Only select repositories**. Credentials do
   not change, so there is no new secret.
2. Copy an existing runner directory and adjust three things — the resource names, the
   `githubConfigUrl`, and the `runner:` label the NetworkPolicy selects on:

   ```sh
   R=kubernetes/apps/actions-runner-system/actions-runner-controller/runners
   cp -r $R/shareviewer $R/<newrepo>
   sed -i 's/shareviewer-runner/<newrepo>-runner/g' $R/<newrepo>/*.yaml
   # then edit githubConfigUrl in $R/<newrepo>/helmrelease.yaml
   ```

3. Add `- ./<newrepo>` to [`runners/kustomization.yaml`](../kubernetes/apps/actions-runner-system/actions-runner-controller/runners/kustomization.yaml).
4. Workflows in that repo then use `runs-on: <newrepo>-runner`.

Keep `githubConfigSecret: github-app-secret` as-is — it is shared deliberately. And re-read the
`maxRunners` note below: each scale set raises the cluster-wide ceiling.

## 🐳 Docker builds

`shareviewer-runner-dind` exists for the jobs the kubernetes-mode sets cannot run. Target it
explicitly:

```yaml
jobs:
  build:
    runs-on: shareviewer-runner-dind
```

Reach for it only when a job genuinely needs a Docker daemon — a Dockerfile-based container action,
`docker build`, `docker run`. Everything else belongs on `shareviewer-runner`, which is
unprivileged. How to tell a container action apart: its `action.yml` says `runs.using: docker` with
`image: 'Dockerfile'`. If it instead says `image: 'docker://…'` the image is prebuilt and the
kubernetes-mode set handles it fine.

How it differs from the other sets:

- A **privileged** `dind` sidecar runs `dockerd`. This is the one privileged pod in the cluster, and
  the reason `maxRunners` is 1 and the network policy still applies.
- The runner gets the chart's `…-no-permission` ServiceAccount — no Kubernetes API access at all,
  unlike kubernetes mode which needs pod-create rights.
- The work volume is an `emptyDir`, not a cephfs PVC: the job runs inside the runner pod, so nothing
  needs to share the volume across pods.
- `/var/lib/docker` is the dind container's writable layer, so image pulls and build layers consume
  **node** ephemeral storage. An `ephemeral-storage: 20Gi` limit bounds a runaway build to an
  evicted pod rather than a full node.

The chart hardcodes `image: docker:dind` with no values knob, so the HelmRelease pins it through
`spec.postRenderers`. That patch is index-based — kustomize has no schema for the
`AutoscalingRunnerSet` CRD and would treat a strategic-merge patch on `initContainers` as a
whole-list replace — so it opens with a JSON-patch `test` on the container's name. If a future chart
version reorders the init containers, the render fails loudly instead of rewriting the wrong image.
Do **not** add `initContainers` to `values.template.spec`: in dind mode the chart generates its own
and appends yours, producing duplicate container names and an invalid pod.

## ⚠️ Constraints

- **The kubernetes-mode sets cannot build containers.** They run each step as its own pod with no
  Docker daemon, so `docker build`, `docker run` and **Dockerfile-based container actions** fail with
  `Building container actions is not currently supported`. They *can* run container actions that
  reference a prebuilt image (`image: docker://…`) and job-level `container:`. For anything that
  needs a real daemon, use `runs-on: shareviewer-runner-dind` — see [Docker builds](#-docker-builds).
- **`maxRunners` is 2 for the kubernetes-mode sets and 1 for dind**, so the cluster-wide ceiling is
  5 concurrent runners across three 6 CPU / ~15Gi nodes. Requests are small (100m/512Mi per
  container) but the 4Gi memory *limit* each means a busy moment can lean hard on nodes that are
  already fairly committed. Check headroom before raising any of them, and remember each new scale
  set raises the ceiling again.
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
