# Findings

## Talos FW, needs to allow access from pods in cluster to kube api

```bash
kubectl run -it --rm --image=busybox test-pod -- sh
wget --no-check-certificate -O - https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
```

## Cleaning up prometheus-stack leftovers for reinstall

When reinstalling kube-prometheus-stack there may be issues with the new installation.
Before proceeding, make sure all resources are cleaned:

```bash
kubectl api-resources --verbs=list -o name \
  | xargs -n 1 kubectl get --show-kind --ignore-not-found -n kube-system -o name \
  | grep kube-prometheus-stack \
  | xargs -n 1 kubectl delete -A
```

[source](https://github.com/prometheus-community/helm-charts/issues/1762)

## Documentations

- [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/introduction/)
- [ArtifatcHub](https://artifacthub.io)
- [OpenTelemetry](https://opentelemetry.io)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes x509](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certificates)

## Cleanup Pods after `talosctl reboot`

```bash
kubectl delete pod --field-selector=status.phase==Suceeded -A
kubectl delete pod --field-selector=status.phase==Failed -A
```

Note: this is now also implemented with a cleanup policy in kyverno:
[cleanup-finished-pods](../infrastructure/policy/configs/policies.yaml#L43)
