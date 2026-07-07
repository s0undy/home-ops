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
    test -f "{{ talos_dir }}/talconfig.yaml" || just log fatal "Missing talconfig" file "{{ talos_dir }}/talconfig.yaml"
    for bin in talhelper talosctl sops; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    cd "{{ talos_dir }}"
    [ -f talsecret.sops.yaml ] || talhelper gensecret | sops --filename-override talos/talsecret.sops.yaml --encrypt /dev/stdin > talsecret.sops.yaml
    talhelper genconfig
    talhelper gencommand apply --extra-flags="--insecure" | bash
    until talhelper gencommand bootstrap | bash; do sleep 10; done
    until talhelper gencommand kubeconfig --extra-flags="{{ justfile_dir() }} --force" | bash; do sleep 10; done

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
