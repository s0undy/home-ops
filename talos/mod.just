set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Generate Talos configuration')]
generate-config:
    test -f "{{ source_directory() }}/talconfig.yaml" || just log fatal "Missing talconfig" file "{{ source_directory() }}/talconfig.yaml"
    test -f "{{ justfile_dir() }}/.sops.yaml" || just log fatal "Missing SOPS config" file "{{ justfile_dir() }}/.sops.yaml"
    test -f "${SOPS_AGE_KEY_FILE}" || just log fatal "Missing SOPS age key" file "${SOPS_AGE_KEY_FILE}"
    command -v talhelper &>/dev/null || just log fatal "Binary not found" binary talhelper
    cd "{{ source_directory() }}"
    talhelper genconfig

[confirm('Apply Talos config to node? [y|N]')]
[doc('Apply Talos config to a node')]
apply-node node mode="auto":
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in talhelper talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    talosctl --nodes "{{ node }}" get machineconfig &>/dev/null || just log fatal "Unable to fetch machineconfig" node "{{ node }}"
    cd "{{ source_directory() }}"
    talhelper gencommand apply --node "{{ node }}" --extra-flags '--mode={{ mode }}' | bash

[confirm('Upgrade Talos on node? [y|N]')]
[doc('Upgrade Talos version on a node')]
upgrade-node node:
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in kubectl talhelper talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    talosctl --nodes "{{ node }}" get machineconfig &>/dev/null || just log fatal "Unable to fetch machineconfig" node "{{ node }}"
    cd "{{ source_directory() }}"
    TALOS_IMAGE=$(yq -r '.nodes[] | select(.ipAddress == "{{ node }}") | .talosImageURL' talconfig.yaml)
    TALOS_VERSION=$(yq -r '.talosVersion' talenv.yaml)
    talhelper gencommand upgrade --node "{{ node }}" --extra-flags "--image='${TALOS_IMAGE}:${TALOS_VERSION}' --timeout=10m" | bash

[confirm('Upgrade Kubernetes on the cluster? [y|N]')]
[doc('Upgrade Kubernetes')]
upgrade-k8s:
    test -f "${TALOSCONFIG}" || just log fatal "Missing talosconfig" file "${TALOSCONFIG}"
    for bin in talhelper talosctl yq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    talosctl config info &>/dev/null || just log fatal "Unable to read Talos config"
    cd "{{ source_directory() }}"
    KUBERNETES_VERSION=$(yq -r '.kubernetesVersion' talenv.yaml)
    talhelper gencommand upgrade-k8s --extra-flags "--to '${KUBERNETES_VERSION}'" | bash

[confirm('This will destroy your cluster and reset the nodes back to maintenance mode... continue? [y|N]')]
[doc('Resets nodes back to maintenance mode')]
reset force="false":
    command -v talhelper &>/dev/null || just log fatal "Binary not found" binary talhelper
    cd "{{ source_directory() }}"
    extra_flags="--reboot --graceful=false --wait=false"
    if [[ "{{ force }}" == "false" ]]; then
        extra_flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false"
    fi
    talhelper gencommand reset --extra-flags="$extra_flags" | bash
