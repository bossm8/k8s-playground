# OpenTelemetry Auto-Instrumentation

OpenTelemetry Operator is installed in the infra-observability namespace, which
means we can leverage the
[auto-instrumentation feature](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/)
to provide traces for many applications.

To do so, create an instrumentation CRD in the namespace where traces should be
created with the jager installation as endpoint:

```yaml
---
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: auto-instrumentation
  namespace: my-namespace
spec:
  exporter:
    endpoint: http://jaeger.infra-observability:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
```

Then the pods need to receive the following annotations and labels for tracing
to work:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-<lang>: 'true'
labels:
  k8s.mcathome.ch/allow-tracing: 'true'
```
