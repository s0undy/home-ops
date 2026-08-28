set default-list
set default-script
set no-exit-message
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

talos_dir := justfile_dir() / 'talos'

[doc('Bootstrap the Talos cluster')]
talos:
    test -f "{{ justfile_dir() }}/.sops.yaml" || just log fatal "Missing SOPS config" file "{{ justfile_dir() }}/.sops.yaml"
    test -f "${SOPS_AGE_KEY_FILE}" || just log fatal "Missing SOPS age key" file "${SOPS_AGE_KEY_FILE}"
    test -f "{{ talos_dir }}/topf.yaml" || just log fatal "Missing topf config" file "{{ talos_dir }}/topf.yaml"
    for bin in topf talosctl sops jq; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    cd "{{ talos_dir }}"
    topf --confirm=false secrets >/dev/null
    # topf falls back to writing the bundle in plaintext if `sops encrypt` fails,
    # so fail loudly rather than leaving unencrypted secrets on disk
    [[ "$(sops filestatus talsecret.sops.yaml | jq -r .encrypted)" == "true" ]] \
        || just log fatal "Secrets bundle is not encrypted" file "{{ talos_dir }}/talsecret.sops.yaml"
    topf talosconfig > "${TALOSCONFIG}"
    chmod 600 "${TALOSCONFIG}"
    topf --confirm=false apply --auto-bootstrap
    # topf kubeconfig only issues a 12h credential, so use talosctl for the persistent one
    until talosctl kubeconfig --force "{{ justfile_dir() }}"; do sleep 10; done

[doc('Bootstrap apps into the Talos cluster')]
apps:
    if [[ "{{ os() }}" == "macos" ]]; then
        [[ -f /opt/homebrew/bin/bash || -f /usr/local/bin/bash ]] || just log fatal "Unsupported bash version, run 'brew install bash' to upgrade"
    fi
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    test -f "{{ justfile_dir() }}/.sops.yaml" || just log fatal "Missing SOPS config" file "{{ justfile_dir() }}/.sops.yaml"
    test -f "${SOPS_AGE_KEY_FILE}" || just log fatal "Missing SOPS age key" file "${SOPS_AGE_KEY_FILE}"
    test -f "{{ justfile_dir() }}/scripts/bootstrap-apps.sh" || just log fatal "Missing bootstrap script" file "{{ justfile_dir() }}/scripts/bootstrap-apps.sh"
    bash "{{ justfile_dir() }}/scripts/bootstrap-apps.sh"
