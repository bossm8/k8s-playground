# Home Lab K8s Cluster on Talos Linux

This repo contains some deployment configurations and helpers for my Kubernetes
playground. It is a single node cluster running on [Talos Linux]().
Manifests in this repository are deployed with [FluxCD]().

## Installed Tools

### Core

- Cilium CNI (TBD)
- Local Path Provisioner

### GitOps

- FluxCD

### Monitoring

- Prometheus
- Vector
- Loki
- OpenTelemetry Collector
- Tempo
- Grafana

### Ingress Controllers

- Traefik
- Nginx
- Cert-Manager

### Policy Enforcement

- Kyverno

## Additional Functionalities

- Tenant Playground Namespaces
