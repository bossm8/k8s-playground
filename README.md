# Home Lab K8s Cluster on Talos Linux

This repo contains some deployment configurations and helpers for my Kubernetes
playground. It is a single node cluster running on [Talos Linux](https://talos.dev)
Manifests in this repository are deployed with [FluxCD](https://fluxcd.io).

## Installed Tools

### Core

- [Cilium CNI](https://cilium.io)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)

### GitOps

- [FluxCD](https://fluxcd.io)

### Monitoring

- [Prometheus](https://prometheus.io)
  ([kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack))
- [Vector](https://vector.dev)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Loki](https://grafana.com/oss/loki)
- [Tempo](https://grafana.com/oss/tempo)
- [Grafana](https://grafana.com/oss/grafana)
- [Nova](https://nova.docs.fairwinds.com)

### Ingress Controllers

- [Traefik](https://traefik.io/traefik)
- [Ingress-Nginx](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager](https://cert-manager.io)

### Policy Enforcement

- [Kyverno](https://kyverno.io)

## Additional Functionalities

- Tenant Playground Namespaces
