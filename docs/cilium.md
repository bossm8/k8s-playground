# Cilium Setup Documentation

## NetworkPolicy Labels

The following labels can be set on pods to allow certain traffic:

- `k8s.mcathome.ch/allow-tracing: 'true'`: Allow sending traces from the pod to jaeger via grpc or http

    [install](../infrastructure/observability/traces/netpol.yaml)
- `k8s.mcathome.ch/allow-kube-api: 'true'`: Allow kube-api access for the pod

    [install](../infrastructure/networking/policies/global.yaml)
- `k8s.mcathome.ch/allow-traefik-ingress: 'true'` Allow traefik ingress controller to forward traefik to the pod (all ports)

    [install](../infrastructure/controllers/ingress/base/netpol.yaml)

## MitM

Network policies can be configured to break open tls connections for any kind of
pod, if the pod can be configured to trust a custom ca. This is normally
possible with environment variables such as `SSL_CERT_FILE` (go) or
`CURL_CA_BUNDLE` for example or by overriding the default trust store in containers.

Such a mitm setup allows to inspect all http content in the packets and allows
for finer netpol configuration.

To enable this we need multiple components:

- [Cilium Installed with TLS visibility](https://docs.cilium.io/en/latest/security/tls-visibility/)

    [install](../infrastructure/networking/cni/base/values/flux.yml)
- [Cert-Manager](https://cert-manager.io/docs)

    [install](../infrastructure/controllers/certs/release/cert-manager/sync.yaml)
- [Trust-Manager](https://cert-manager.io/docs/trust/trust-manager/)

    [install](../infrastructure/controllers/certs/release/trust-manager/sync.yaml)
- [Trust Bundle for envoy to internet trust](https://cert-manager.io/docs/trust/trust-manager/#usage)

    [install](../infrastructure/controllers/certs/config/sync.yaml)
- [Cilium CA Certificate](../infrastructure/controllers/certs/config/sync.yaml)
- [ClusterIssuer using the Cilium CA Certificate](https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers)

    [install](../infrastructure/controllers/certs/config/sync.yaml)
- Global wildcard cert for envoy TLS termination issued with Cilium CA certificate
- [Trust Bundle for service to envoy TLS trust](https://cert-manager.io/docs/trust/trust-manager/#usage)

    [install](../infrastructure/controllers/certs/config/sync.yaml)

- CiliumNetworkPolicy (see below for an example)

Example Certificate and CNP for TLS visibility, assuming the CA ClusterIssuer
`cilium-mitm-ca` exists:

```yaml
---
# Globally installed, only once, for originating TLS trust (envoy <-> internet)
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
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cilium-mitm-cert
  namespace: cert-manager
spec:
  commonName: mitm.k8s.mcathome.ch
  dnsNames:
  - <All required (wildcard) dns names (when used globally)>
  secretName: cilium-mitm-cert
  issuerRef:
    name: cilium-mitm-ca
    kind: ClusterIssuer
---
# Syncs the MitM ca truststore to all namespaces for client trust (service <-> envoy)
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: cilium-mitm-trust-bundle
spec:
  sources:
  - useDefaultCAs: false
  - secret:
      name: cilium-mitm-cert
      key: ca.crt
  target:
    secret:
      key: ca.crt
    additionalFormats:
      pkcs12:
        key: cacerts
---
# Mount the cilium-mitm-trust-bundle to a location in any pod and point
# client libraries to use the ca.crt (pem) or cacerts (pkcs12) as trust
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: mitm
  namespace: my-namespace
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
        # Use the wildcard cert created above
        # Will be synced by cilium to cilium-secrets if not yet there
        secret:
          name: cilium-mitm-cert
          namespace: cert-manager
      originatingTLS:
        # Created by trust-manager with only useDefaultCAs: true (see above)
        secret:
          name: ca-certificates
          namespace: cert-manager
      rules:
        http: [{}]
```

Alternatively (better): use one cert per netpol for the service domains and
just use the global trust bundle for trust in pods.
