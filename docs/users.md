# User Playground

The cluster provides functionality to add new users (aka tenants) to the cluster.
They will be allowed to create and manage namespaces prefixed with their username.

## Add User

To create a new user, use the helper script `create-user.sh`:

```bash
/bin/bash helpers/create-user.sh <username> <talos-controlplane.yaml>
```

This will create a new kubeconfig in the current working directory with a user
which has basic namespace creation permissions.

## Tenancy Enforcement

When the user creates a new namespace, the namespace will be assigned tenancy
label `k8s.mcathome.ch/tenant: <username>`. This label is used to create a default
network policy which allows communication with all resources in namespaces
of the same tenant and with the internet. The user will also get permissions
to manage core api resources as well as listing the networking resources with
the [namespace-owner role](../applications/user-playground/playground-roles.yaml).

This functionality is provided by the kyverno policy
"[Multi-Tenancy Playground](../applications/user-playground/playground-policies.yaml)"
