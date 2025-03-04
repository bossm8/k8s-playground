# Findings

## Talos FW, needs to allow access from pods in cluster to kube api

```bash
kubectl run -it --rm --image=busybox test-pod -- sh
wget --no-check-certificate -O - https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
```

(TBD: why 6443?)
