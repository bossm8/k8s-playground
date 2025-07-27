# Installation Doc

**Note**: this is a relatively specific installation instruction to this repo,
if you want to reproduce this you may need to adjust some of the commands
mentioned in the documentation here.

## Prerequisites

- [flux](https://fluxcd.io/flux/installation/)
- [helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [talosctl](https://www.talos.dev/v1.9/talos-guides/install/talosctl/)

## Step-by-Step

1. Burn the [talos ISO image](https://www.talos.dev/v1.9/talos-guides/install/bare-metal-platforms/iso/)
   onto a USB stick
2. Follow the [talos installation guide](https://www.talos.dev/v1.9/introduction/getting-started/)
   ([talos.md](./talos.md) contains some adjustments to the `controlplane.yaml`)

   In general:

   - Genereate talos secrets: `talosctl gen secrets -o secrets.yaml`
   - Generate configuration:
     `talosctl gen config --with-secrets secrets.yaml <cluster-name> <single-node-local-ip>`
   - Move the `talosconfig` to `~/.talos/config` to be picked up as default
   - Apply the intial configuration:
     `talosctl apply config --insecure --nodes <single-node-local-ip> --file controlplane.yaml`
   - Edit the `talosconfig` and add `endpoints` and `nodes` with the single node
     local IP: `contexts.<cluster>.(endpoints|nodes)[<single-node-cluster-ip>]`
   - Bootstrap the cluster: `talosctl bootstrap`
   - Apply the patch documented in [talos.md](./talos.md):
     `talosctl patch mc --patch @config/controlplane-patch.yaml --mode try` Mode
     try is important since the firewall rules may block talosctl or kubectl
     from connecting when configured incorrectly.  When everything works as
     expected, the config can be applied.  (Possibly also a `talosctl
     upgrade-k8s` may be needed so that pods get restarted with the added
     arguments)
   - Generate the kubeconfig `talosctl gen kubeconfig`
   - Store the patch and the `secrets.yaml` securely (patch can be added to a
     repo unencrypted if it contains no secrets)

3. Install Cilium CNI

   With the patch documented in [talos.md](./talos.md) the default CNI
   installation as well as the kube-proxy are disabled. This means a different
   CNI needs to be installed.  this can be done with the
   [helper script](../helpers/install-cilium.sh).

4. Bootstrap flux into the cluster (with a deploy key to this repo)

   - Create a GitHub repo and add a deploy key genereted with e.g. `ssh-keygen`
   - Use the deploy key to bootstrap flux:

   ```bash
   flux bootstrap git \
    --url ssh://git@github.com/bossm8/k8s-playground.git \
    --branch main \
    --private-key-file ~/flux-k8s.key \
    --path clusters/mcathome
   ```

5. The initialisation of _this_ repo will fail, since the deploy key to the
   private repo containing the variables is not yet configured, and the SOPS key
   used to decrypt some of the variables is not yet present. Create the
   necessary secret manually:

   - Deploy key:

      ```bash
      flux create secret git k8s-playground-vars \
       --private-key-file ~/flux-k8s-vars.key \
       --url ssh://git@github.com/bossm8/k8s-playground-vars.git
      ```

   - [SOPS](https:getsops.io) secret with [age](https://github.com/FiloSottile/age):
      (Documentation about how to create age keys and encrypt secrets can be
      found
      [here (flux)](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age)
      and [here (sops)](https://getsops.io/docs/#encrypting-using-age))

      ```bash
      cat age.agekey | kubectl create secret generic sops-age \
         --namespace flux-system \
         --from-file age.agekey=/dev/stdin
      ```

6. Update Cilium CNI

   When Prometheus has installed the CRDs in the cluster the [cilium helper
   script](../helpers/install-cilium.sh) can be re-run with the
   `--with-prometheus` flag, this will install ServiceMonitors and Grafana
   dashboards for cilium services into the cluster.

7. Intall Extensions

   To install system extension head to [factory.talos.dev](https://factory.talos.dev),
   select the extensions to install and run the following command:

   ```bash
   talosctl upgrade -i factory.talos.dev/metal-installer/<generated-id>:<tag>
   ```
