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

1. Burn the [talos ISO image](https://www.talos.dev/v1.9/talos-guides/install/bare-metal-platforms/iso/) onto a USB stick
2. Follow the [talos installation guide](https://www.talos.dev/v1.9/introduction/getting-started/) ([talos.md](./talos.md) contains some adjustments to the `controlplane.yaml`)
3. Bootstrap flux into the cluster (with a deploy key to this repo)

   ```bash
   flux bootstrap git \
    --url ssh://git@github.com/bossm8/k8s-playground.git \
    --branch main \
    --private-key-file ~/flux-k8s.key \
    --path clusters/mcathome
   ```

4. The initialisation will fail, since the deploy key to the private repo
   containing the variables is not yet configured, and the SOPS key used to
   decrypt some of the variables is not yet present. Create the necessary secret
   manually:
  
   - Deploy key:

      ```bash
      flux create secret git k8s-playground-vars \
       --private-key-file ~/flux-k8s-vars.key \
       --url ssh://git@github.com/bossm8/k8s-playground-vars.git
      ```

   - SOPS secret:

      (TBD)
