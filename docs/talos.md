# Documentation about talos adjustments

Find adjustments needed to the talos configuration in order to setup a
single-node k8s cluster with talos.

Note: after each adjustment, run
`taloctl apply config -f <path-to-config>/controlplane.yaml`,
this document assumes the talos cluster was already bootstrapped.

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
