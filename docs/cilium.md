# Cilium Setup Documentation

## MitM

Network policies can be configured to break open tls connections for any kind of
pod, if the pod can be configured to trust a custom ca. This is normally
possible with environment variables such as `SSL_CERT_FILE` (go) or
`CURL_CA_BUNDLE` for example.

Such a mitm setup allows to inspect all http content in the packets and allows
for finer netpol configuration.

To enable this we need multiple components:

- [Cilium Installed with TLS visibility](https://docs.cilium.io/en/latest/security/tls-visibility/)
    [install](../infrastructure/networking/cni/base/values/flux.yml)
- [Cert-Manager](https://cert-manager.io/docs)
    [install](../infrastructure/controllers/certs/release/sync.yaml)
- [Trust-Manager](https://cert-manager.io/docs/trust/trust-manager/)
    [install](../infrastructure/controllers/certs/release/sync.yaml)
- [Trust Bundle for egress TLS initiation](https://cert-manager.io/docs/trust/trust-manager/#usage)
    [install](../infrastructure/controllers/certs/config/sync.yaml)
- [Cilium CA Certificate](../infrastructure/controllers/certs/config/sync.yaml)
- [ClusterIssuer using the Cilium CA Certificate](https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers)
    [install](../infrastructure/controllers/certs/config/sync.yaml)
- Service Certificates issued by Cilium CA Certificate (see below)
- CiliumNetworkPolicy (see below)

Example Certificate and CNP for TLS visibility, assuming the CA ClusterIssuer
`cilium-mitm-ca` exists:

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cilium-mitm
  namespace: my-namespace
spec:
  commonName: foo.bar
  dnsNames:
  - foo.bar
  - bar.foo
  secretName: cilium-mitm
  issuerRef:
    name: cilium-mitm-ca
    kind: ClusterIssuer
---
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: ca-certificates
  namespace: cert-manager
spec:
  sources:
  - useDefaultCAs: true
  target:
    secret:
      key: ca.crt
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: cert-manager
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-geoip-update
  namespace: infra-observability
spec:
  endpointSelector:
    matchLabels:
      my-label: my-value
  egress:
  - toFQDNs:
    - matchName: foo.bar
    - matchName: bar.foo
    toPorts:
    - ports:
      - port: '443'
        protocol: TCP
      terminatingTLS:
        secret:
          name: cilium-mitm
          namespace: my-namespace
      originatingTLS:
        # Created by trust-manager with only useDefaultCAs: true
        secret:
          name: ca-certificates
          namespace: cert-manager
      rules:
        http: [{}]
```