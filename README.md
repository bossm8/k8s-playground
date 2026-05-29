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

### Security

- [Trivy Operator](https://aquasecurity.github.io/trivy-operator/latest/)
- [Falco](https://falco.org/)

## Additional Functionalities

- Tenant Playground Namespaces

## Local Development

The cluster can be run completely locally with devcontainers (and enough resources).
For more information check out
[the Medium post](https://medium.com/@bossm8/running-fluxcd-locally-gitops-for-kubernetes-on-your-laptop-7842b89d67b7).

There may be networking issues when using colima/rancher desktop on Apple
silicon, which both use lima under the hood, I often saw errors like 'dial tcp
<IP>:443 i/o timeout' to already resolved IPs (no DNS issue).

Local Stack:

- VSCode managed containers:
  - Lightweight git server for hosting the shadow copy of this repo for near immediate local flux reconciliation
  - [Zot](https://zotregistry.dev/) a local pull through OCI image cache for k8s workload images
    Check cached repos by using this url: http://localhost:5000/v2/_catalog (UI sometimes does not show all images)
  - Actual devcontainer with all necessary tools installed
- Started with `make` in the devcontainer
  - Kind cluster, [configured using the local OCI mirror](./.devcontainer/assets/cluster.yml)
  - Flux installed in the cluster, referencing the manifests pushed on change in the IDE

Other local assets:
- [Colima configuration](./.devcontainer/assets/colima.yaml) which I tried to make everything running despite networking issues.
  This can be installed under `~/.colima/<profile>/colima.yaml` and then started using `colima start --profile <profile`.
  Commands are also available as make target `setup-colima`
