# Documentation about talos adjustments

Find adjustments needed to the talos configuration in order to setup a
single-node k8s cluster with talos.

**Notes**:

- When adjusting manually, after each adjustment, run
  `taloctl apply config -f <path-to-config>/controlplane.yaml`,
  this document assumes the talos cluster was already bootstrapped.
- The commands here assume, that endpoints and nodes have been configured in
  the talos config (default `~/talos/config`).
  (`contexts.<cluster>.endpoints[<single-node-cluster-ip>]`
  and `contexts.<cluster>.nodes[<single-node-cluster-ip>]`)

## Single Node Cluster

After running `talosctl get config <cluster> <endpoint>`, edit the
`controlplane.yaml` and set `cluster.allowSchedulingOnControlPlanes: true`.

[source](https://www.talos.dev/v1.9/talos-guides/howto/workers-on-controlplane/)

## Local storage

To enable mounting the node storage into pods, the `controlplane.yaml` needs to
be adjusted to mount the local disk to the kubelet container.

```yaml
machine:
  kubelet:
    extraMounts:
      - destination: /var/mnt
        type: bind
        source: /var/mnt
        options:
          - bind
          - rshared
          - rw
```

Then, the [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
needs to be installed.
See the [HelmRelease](/infrastructure/storage/local-path-provisioner.yaml) for
reference.

[source](https://www.talos.dev/v1.8/kubernetes-guides/configuration/local-storage/)

## Kube Metrics with kube-prometheus-stack

**NOTE**: These changes will open the ports on the node, so be careful.

In order to query metrics from kubernetes components, we need to change the
listening ports of the pods deployed by talos:
Add the extra argument to the proxy pod:
`cluster.proxy.extraArgs: [metrics-bind-address: 0.0.0.0:10249]`

Similar configuration changes are neede for the `controller-manager` and the
`scheduler`. But there the `extraArgs` are `[bind-address: 0.0.0.0]`.

And etcd: `extraArgs: [listen-metrics-urls: http://0.0.0.0:2381]`
Still, this also needs an additional change in the HelmRelease as etcd is not
running as pod in talos. Add the following to the `values` section:

```yaml
kubeEtcd:
  endpoints:
    - <node-local-network-ip>
```

(this might change also require `talosctl upgrade-k8s`)

[source 1](https://github.com/siderolabs/talos/discussions/7799)
[source 2](https://github.com/prometheus-operator/kube-prometheus/issues/718)
[source 3](https://github.com/siderolabs/talos/discussions/7214)

### Ingress Firewall

**NOTE**: It's advised to wait with this until the cluster is setup. It can then
be applied with --mode=try to see if all works before enforcing it

Since we opened the services on all interfaces, we now make sure to block
request coming from external, allowing only API and HTTP/HTTPS traffic.

Add the following to the `controlplane.yaml`:

```yaml
---
apiVersion: v1alpha1
kind: NetworkDefaultActionConfig
ingress: block
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: talos-apid
portSelector:
  ports:
    - 50000
  protocol: tcp
ingress:
  - subnet: 192.168.178.0/24
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: kubectl-ingress
portSelector:
  ports:
    - 6443
  protocol: tcp
ingress:
  - subnet: 192.168.178.0/24
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: http-ingress-tcp
portSelector:
  ports:
    - 80
    - 443
  protocol: tcp
ingress:
  - subnet: 192.168.178.0/24
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: http-ingress-udp
portSelector:
  ports:
    - 80
    - 443
  protocol: udp
ingress:
  - subnet: 192.168.178.0/24
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: etcd-ingress
portSelector:
  ports:
    - 2379-2380
  protocol: tcp
ingress:
  - subnet: 192.168.178.74/32
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: cni-vxlan-udp
portSelector:
  ports:
    - 4789
  protocol: udp
ingress:
  - subnet: 10.244.0.0/16  # Pod network
  - subnet: 10.96.0.0/12   # Kubernetes services
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: cni-vxlan-tcp
portSelector:
  ports:
    - 4789
  protocol: tcp
ingress:
  - subnet: 10.244.0.0/16  # Pod network
  - subnet: 10.96.0.0/12   # Kubernetes services
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: talos-trustd
portSelector:
  ports:
    - 50001
  protocol: tcp
ingress:
  - subnet: 10.244.0.0/16     # Pod network
  - subnet: 10.96.0.0/12      # Kubernetes services
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: kubelet-ingress
portSelector:
  ports:
    - 10250
  protocol: tcp
ingress:
  - subnet: 10.244.0.0/16     # Pod network
  - subnet: 10.96.0.0/12      # Kubernetes services
```

## DNS Settings

To use differend DNS servers, adjust the `machine.network.nameservers`. For example:

```yaml
machine:
  network:
    nameservers:
      - 192.168.178.1 # Use local network gateway first to enable Pi-Hole protection
      - 9.9.9.9 # Quad 9
      - 8.8.8.8
```

## Automatic Patching

Instead of adding the changes mentioned above manually to the file
talosctl can be leveraged to 
[apply patches](https://www.talos.dev/v1.5/talos-guides/configuration/patching/).
The [patch](./controlplane-patch.yaml) can be used like this:

```bash
talosctl machineconfig patch \
  --patch @controlplane-patch.yaml \
  ~/controlplane.yaml
```

Or directly on the node when the default was installed:

```bash
talosctl patch mc --patch @controlplane-patch.yaml
```
