# 🚀 Bootstrap & Maintenance

A runbook for bringing this cluster up from scratch and keeping it maintained. Assumes the repository is already cloned and the nodes are booted into Talos maintenance mode.

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Cloudflare configuration](#-cloudflare-configuration)
- [Bootstrap the cluster](#-bootstrap-the-cluster)
- [GitHub webhook](#-github-webhook)
- [Talos & Kubernetes maintenance](#️-talos--kubernetes-maintenance)
- [Debugging](#-debugging)

## 🔧 Prerequisites

1. **Install** the [Mise CLI](https://mise.jdx.dev/getting-started.html#installing-mise-cli) on your workstation.

2. **Activate** Mise in your shell by following the [activation guide](https://mise.jdx.dev/getting-started.html#activate-mise).

3. Use `mise` to install the **required** CLI tools:

    ```sh
    mise trust
    pip install pipx
    mise install
    ```

## ☁️ Cloudflare configuration

> [!WARNING]
> If any of the commands fail with `command not found` or `unknown command` it means `mise` is either not installed, activated, or configured incorrectly.

1. Create a Cloudflare API token for use with cloudflared and external-dns by reviewing the official [documentation](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) and following the instructions below.

   - Click the blue `Use template` button for the `Edit zone DNS` template.
   - Name your token `kubernetes`.
   - Under `Permissions`, click `+ Add More` and add permissions `Zone - DNS - Edit` and `Account - Cloudflare Tunnel - Read`.
   - Limit the permissions to a specific account and/or zone resources, then click `Continue to Summary` and `Create Token`.
   - **Save this token somewhere safe**, you will need it later on.

2. Create the Cloudflare Tunnel:

    ```sh
    cloudflared tunnel login
    cloudflared tunnel create --credentials-file cloudflare-tunnel.json kubernetes
    ```

## 🥾 Bootstrap the cluster

1. Install Talos onto the nodes (generates secrets, applies config, bootstraps etcd and fetches the kubeconfig):

    ```sh
    task bootstrap:talos
    ```

2. Install Cilium, CoreDNS, Spegel, Flux and sync the cluster to the repository state:

    ```sh
    task bootstrap:apps
    ```

3. Watch the rollout of the cluster happen:

    ```sh
    kubectl get pods --all-namespaces --watch
    ```

## 🪝 GitHub webhook

By default Flux will periodically check the git repository for changes. To have Flux reconcile on `git push` you must configure GitHub to send `push` events to Flux.

1. Obtain the webhook path:

   📍 _Hook id and path should look like `/hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123`_

    ```sh
    kubectl -n flux-system get receiver github-webhook --output=jsonpath='{.status.webhookPath}'
    ```

2. Piece together the full URL with the webhook path appended:

    ```text
    https://flux-webhook.${cloudflare_domain}/hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
    ```

3. Navigate to the repository settings on GitHub. Under **Settings → Webhooks** press **Add webhook**. Fill in the webhook URL and the token from `github-push-token.txt`, set Content type to `application/json`, choose **Just the push event**, and save.

## 🛠️ Talos & Kubernetes maintenance

### ⚙️ Updating Talos node configuration

> [!TIP]
> Ensure you have updated `talconfig.yaml` and any patches with your updated configuration. In some cases you **not only need to apply the configuration but also upgrade Talos** to apply the new configuration.

```sh
# (Re)generate the Talos config
task talos:generate-config

# Apply the config to a node (MODE defaults to auto)
task talos:apply-node IP=? MODE=?
# e.g. task talos:apply-node IP=10.0.100.11 MODE=auto
```

### ⬆️ Updating Talos and Kubernetes versions

> [!TIP]
> Ensure the `talosVersion` and `kubernetesVersion` in `talenv.yaml` are set to the versions you wish to upgrade to.

```sh
# Upgrade a single node to a newer Talos version
task talos:upgrade-node IP=?
# e.g. task talos:upgrade-node IP=10.0.100.11
```

```sh
# Upgrade the cluster to a newer Kubernetes version
task talos:upgrade-k8s
```

### ➕ Adding a node to the cluster

Keep in mind it is recommended to have an **odd number** of control plane nodes for quorum reasons. You don't need to re-bootstrap the cluster to add new nodes.

1. **Prepare the new node**: boot it into Talos maintenance mode.

2. **Get the node information**: while the node is in maintenance mode, retrieve the disk and MAC address information needed for configuration:

   ```sh
   talosctl get disks -n <ip> --insecure
   talosctl get links -n <ip> --insecure
   ```

3. **Update the configuration**: read the [talhelper](https://budimanjojo.github.io/talhelper/latest/) documentation and extend `talconfig.yaml` with the new node information (including the disk and MAC address from step 2).

4. **Generate and apply the configuration**:

   ```sh
   task talos:generate-config
   task talos:apply-node IP=?
   # e.g. task talos:apply-node IP=10.0.100.14
   ```

   The node should join the cluster automatically and workloads will be scheduled once it reports as ready.

### 💥 Resetting nodes

> [!CAUTION]
> This destroys the cluster and resets the nodes back to maintenance mode.

```sh
task talos:reset
```

## 🐛 Debugging

A general guide for debugging an issue with a resource or application — for example, when a workload is not showing up or a pod is stuck in `CrashLoopBackOff` or `Pending`. These steps help locate the problem, not fix it, as the cause could be one of many things.

1. Check if the Flux resources are up-to-date and in a ready state:

   📍 _Run `task reconcile` to force Flux to sync the Git repository state._

    ```sh
    flux get sources git -A
    flux get ks -A
    flux get hr -A
    ```

2. Check for the pod of the workload you are debugging:

    ```sh
    kubectl -n <namespace> get pods -o wide
    ```

3. Check the logs of the pod if it's there:

    ```sh
    kubectl -n <namespace> logs <pod-name> -f
    ```

4. If a resource exists, describe it to see what problems it might have:

    ```sh
    kubectl -n <namespace> describe <resource> <name>
    ```

5. Check the namespace events:

    ```sh
    kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
    ```
