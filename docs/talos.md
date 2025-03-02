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
