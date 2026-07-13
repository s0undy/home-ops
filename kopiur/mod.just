set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Show Kopiur resources')]
status:
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    for bin in jq kubectl; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    kubectl get clusterrepositories,maintenances --all-namespaces
    kubectl get snapshotpolicies,snapshotschedules --all-namespaces
    printf 'NAMESPACE\tRESOURCE\tPHASE\n'
    kubectl get snapshots,restores --all-namespaces --output=json \
        | jq --raw-output '.items[] | .status.phase as $phase | select(["Succeeded", "Completed", "Discovered"] | index($phase) | not) | [.metadata.namespace, ((.kind | ascii_downcase) + "/" + .metadata.name), ($phase // "Pending")] | @tsv'

[doc('List snapshots for an app')]
snapshots app ns="":
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    for bin in jq kubectl; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    ns="{{ ns }}"
    if [[ -z "$ns" ]]; then
        mapfile -t detected < <(kubectl get snapshotpolicies --all-namespaces --output=json | jq --raw-output --arg app "{{ app }}" '.items[] | select(.metadata.name == $app) | .metadata.namespace')
        [[ ${#detected[@]} -eq 0 ]] && just log fatal "No SnapshotPolicy found" app "{{ app }}"
        [[ ${#detected[@]} -gt 1 ]] && just log fatal "SnapshotPolicy exists in multiple namespaces, pass ns explicitly" app "{{ app }}"
        ns="${detected[0]}"
    fi
    kubectl --namespace "$ns" get snapshotpolicy "{{ app }}" &>/dev/null || just log fatal "SnapshotPolicy not found" app "{{ app }}" namespace "$ns"
    printf 'NAME\tPHASE\tORIGIN\tSNAPSHOT\tSTARTED\n'
    kubectl --namespace "$ns" get snapshots --output=json \
        | jq --raw-output --arg app "{{ app }}" '.items | map(select(.spec.policyRef.name == $app)) | sort_by(.status.timing.startTime)[] | [.metadata.name, .status.phase, .status.origin, (.status.snapshot.kopiaSnapshotID // "-"), (.status.timing.startTime // "-")] | @tsv'

[doc('Snapshot an app')]
snapshot app ns="":
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    for bin in jq kubectl; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    ns="{{ ns }}"
    if [[ -z "$ns" ]]; then
        mapfile -t detected < <(kubectl get snapshotpolicies --all-namespaces --output=json | jq --raw-output --arg app "{{ app }}" '.items[] | select(.metadata.name == $app) | .metadata.namespace')
        [[ ${#detected[@]} -eq 0 ]] && just log fatal "No SnapshotPolicy found" app "{{ app }}"
        [[ ${#detected[@]} -gt 1 ]] && just log fatal "SnapshotPolicy exists in multiple namespaces, pass ns explicitly" app "{{ app }}"
        ns="${detected[0]}"
    fi
    kubectl --namespace "$ns" get snapshotpolicy "{{ app }}" &>/dev/null || just log fatal "SnapshotPolicy not found" app "{{ app }}" namespace "$ns"
    snapshot="$(kubectl create --output=name --filename - <<EOF
    apiVersion: kopiur.home-operations.com/v1alpha1
    kind: Snapshot
    metadata:
      generateName: {{ app }}-manual-
      namespace: ${ns}
    spec:
      policyRef:
        name: {{ app }}
      tags:
        reason: manual
    EOF
    )"
    echo "Waiting for ${snapshot}"
    kubectl --namespace "$ns" wait "${snapshot}" --for=jsonpath='{.status.phase}'=Succeeded --timeout=120m
    kubectl --namespace "$ns" get "${snapshot}" --output=wide

[confirm('Restore the app PVC in place from the snapshot? This overwrites its current contents... [y|N]')]
[doc('Restore an app in place from a snapshot')]
restore app snapshot ns="":
    test -f "${KUBECONFIG}" || just log fatal "Missing kubeconfig" file "${KUBECONFIG}"
    for bin in flux jq kubectl; do
        command -v "$bin" &>/dev/null || just log fatal "Binary not found" binary "$bin"
    done
    ns="{{ ns }}"
    if [[ -z "$ns" ]]; then
        mapfile -t detected < <(kubectl get snapshotpolicies --all-namespaces --output=json | jq --raw-output --arg app "{{ app }}" '.items[] | select(.metadata.name == $app) | .metadata.namespace')
        [[ ${#detected[@]} -eq 0 ]] && just log fatal "No SnapshotPolicy found" app "{{ app }}"
        [[ ${#detected[@]} -gt 1 ]] && just log fatal "SnapshotPolicy exists in multiple namespaces, pass ns explicitly" app "{{ app }}"
        ns="${detected[0]}"
    fi
    kubectl --namespace "$ns" get snapshot "{{ snapshot }}" &>/dev/null || just log fatal "Snapshot not found" snapshot "{{ snapshot }}" namespace "$ns"
    kubectl --namespace "$ns" get persistentvolumeclaim "{{ app }}" &>/dev/null || just log fatal "PVC not found" pvc "{{ app }}" namespace "$ns"
    restore="{{ app }}-manual-$(date +%s)"
    controller="statefulset"
    kubectl --namespace "$ns" get deployment "{{ app }}" &>/dev/null && controller="deployment"
    puid="$(kubectl --namespace "$ns" get snapshotpolicy "{{ app }}" --output=jsonpath='{.spec.mover.securityContext.runAsUser}')"
    pgid="$(kubectl --namespace "$ns" get snapshotpolicy "{{ app }}" --output=jsonpath='{.spec.mover.securityContext.runAsGroup}')"
    flux --namespace "$ns" suspend kustomization "{{ app }}"
    flux --namespace "$ns" suspend helmrelease "{{ app }}"
    kubectl --namespace "$ns" scale "${controller}/{{ app }}" --replicas 0
    kubectl --namespace "$ns" wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    kubectl create --filename - <<EOF
    apiVersion: kopiur.home-operations.com/v1alpha1
    kind: Restore
    metadata:
      name: ${restore}
      namespace: ${ns}
    spec:
      mover:
        securityContext:
          runAsUser: ${puid}
          runAsGroup: ${pgid}
      options:
        enableFileDeletion: true
      policy:
        onMissingSnapshot: Fail
      source:
        snapshotRef:
          name: {{ snapshot }}
      target:
        pvcRef:
          name: {{ app }}
    EOF
    echo "Waiting for restore/${restore}"
    kubectl --namespace "$ns" wait "restore/${restore}" --for=jsonpath='{.status.phase}'=Completed --timeout=120m
    kubectl --namespace "$ns" get "restore/${restore}" --output=wide
    kubectl --namespace "$ns" delete restore "${restore}"
    flux --namespace "$ns" resume kustomization "{{ app }}"
    flux --namespace "$ns" resume helmrelease "{{ app }}"
    flux --namespace "$ns" reconcile kustomization "{{ app }}" --with-source
    flux --namespace "$ns" reconcile helmrelease "{{ app }}" --force
    kubectl --namespace "$ns" wait pod --for=condition=ready --selector="app.kubernetes.io/instance={{ app }}" --timeout=5m
