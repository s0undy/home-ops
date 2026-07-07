set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Force Flux to pull in changes from your Git repository')]
reconcile:
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    command -v flux &>/dev/null || just log fatal "Binary not found" binary flux
    flux --namespace flux-system reconcile kustomization flux-system --with-source
