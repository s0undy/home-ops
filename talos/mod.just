set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Resolve a hostname or IP from topf.yaml to the node's `host` value, since
# topf's --nodes-filter matches on host rather than IP.
[private]
[script]
resolve-node node:
    cd "{{ source_directory() }}"
    export NODE="{{ node }}"
    host=$(yq -r '.nodes[] | select(.host == strenv(NODE) or .ip == strenv(NODE)) | .host' topf.yaml)
    [[ -n "$host" ]] || just log fatal "Unknown node" node "$NODE"
    echo "$host"

[doc('List nodes and their current state')]
nodes output="table":
    command -v topf &>/dev/null || just log fatal "Binary not found" binary topf
    cd "{{ source_directory() }}"
    topf nodes --output "{{ output }}"

[doc('Render machine configs locally without applying them')]
render output="./output":
    test -f "{{ source_directory() }}/topf.yaml" || just log fatal "Missing topf config" file "{{ source_directory() }}/topf.yaml"
    test -f "${SOPS_AGE_KEY_FILE}" || just log fatal "Missing SOPS age key" file "${SOPS_AGE_KEY_FILE}"
    command -v topf &>/dev/null || just log fatal "Binary not found" binary topf
    cd "{{ source_directory() }}"
    topf --redact=false render --output "{{ output }}"

[doc('Show pending Talos config changes without applying them')]
diff:
    test -f "{{ source_directory() }}/topf.yaml" || just log fatal "Missing topf config" file "{{ source_directory() }}/topf.yaml"
    command -v topf &>/dev/null || just log fatal "Binary not found" binary topf
    cd "{{ source_directory() }}"
    # topf exits 2 when drift is detected, which is not an error here
    topf --confirm=false apply --dry-run || [[ $? -eq 2 ]]

[doc('Generate the talosconfig client config')]
talosconfig:
    test -f "{{ source_directory() }}/topf.yaml" || just log fatal "Missing topf config" file "{{ source_directory() }}/topf.yaml"
    test -f "${SOPS_AGE_KEY_FILE}" || just log fatal "Missing SOPS age key" file "${SOPS_AGE_KEY_FILE}"
    command -v topf &>/dev/null || just log fatal "Binary not found" binary topf
    cd "{{ source_directory() }}"
    topf talosconfig > "${TALOSCONFIG}"
    chmod 600 "${TALOSCONFIG}"
    just log info "Wrote talosconfig" file "${TALOSCONFIG}"

# Talos v1.14 dropped `reboot` as an apply mode; use auto, no-reboot, staged or try.
[confirm('Apply Talos config to node? [y|N]')]
[doc('Apply Talos config to a node')]
apply-node node mode="auto":
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in topf talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    host=$(just talos resolve-node "{{ node }}")
    cd "{{ source_directory() }}"
    topf --confirm=false --nodes-filter "^${host}\$" apply --mode "{{ mode }}"

[confirm('Apply Talos config to ALL nodes? [y|N]')]
[doc('Apply Talos config to every node, one control plane at a time')]
apply:
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in topf talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    cd "{{ source_directory() }}"
    topf --confirm=false apply --mode auto

[confirm('Upgrade Talos on node? [y|N]')]
[doc('Upgrade Talos version on a node')]
upgrade-node node:
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in kubectl topf talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    host=$(just talos resolve-node "{{ node }}")
    cd "{{ source_directory() }}"
    topf --confirm=false --nodes-filter "^${host}\$" upgrade --drain

[confirm('Upgrade Kubernetes on the cluster? [y|N]')]
[doc('Upgrade Kubernetes')]
upgrade-k8s:
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    cd "{{ source_directory() }}"
    # topf has no upgrade-k8s equivalent, so this stays on talosctl
    KUBERNETES_VERSION=$(yq -r '.kubernetesVersion' topf.yaml)
    talosctl upgrade-k8s --to "${KUBERNETES_VERSION#v}"

[confirm('This will destroy your cluster and reset the nodes back to maintenance mode... continue? [y|N]')]
[doc('Resets nodes back to maintenance mode (full=true wipes the entire disk)')]
reset full="false":
    command -v topf &>/dev/null || just log fatal "Binary not found" binary topf
    cd "{{ source_directory() }}"
    topf --confirm=false reset --full={{ full }} --graceful=false
