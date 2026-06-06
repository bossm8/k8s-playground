#!/bin/bash

# Generates a kubeconfig with cluster-wide read-only access using a ServiceAccount
# bound to the built-in 'view' ClusterRole (excludes Secrets by design).
# https://kubernetes.io/docs/reference/access-authn-authz/rbac/#default-roles-and-role-bindings

NAME=$1
DURATION=${2:-8760h}

function usage() {
  echo "Usage: /bin/bash create-readonly-kubeconfig.sh <name> [duration]"
  echo "  name:     ServiceAccount name (chars: a-z and -)"
  echo "  duration: Token duration (default: 8760h)"
}

if test -z "$NAME" || ! [[ "$NAME" =~ ^[a-z-]+$ ]]; then
  echo "Error: Valid name argument is required (allowed chars: a-z and -)"
  usage && exit 1
fi

if ! which kubectl > /dev/null 2>&1; then
  echo "Error: kubectl is required to use this script"
  exit 1
fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "$NAME"
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: "${NAME}-readonly-binding"
  labels:
    app.kubernetes.io/component: readonly-kubeconfig
    app.kubernetes.io/managed-by: create-readonly-kubeconfig.sh
subjects:
  - kind: ServiceAccount
    name: "$NAME"
    namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
EOF

TOKEN=$(kubectl create token "$NAME" -n default --duration="$DURATION")

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

export KUBECONFIG="./${NAME}-kubeconfig"

kubectl config set-cluster "$CLUSTER_NAME" \
  --server="$SERVER" \
  --certificate-authority=<(echo "$CA_DATA" | base64 -d) \
  --embed-certs=true

kubectl config set-credentials "$NAME" \
  --token="$TOKEN"

kubectl config set-context default \
  --cluster="$CLUSTER_NAME" \
  --user="$NAME"

kubectl config use-context default

echo "Info: Kubeconfig written to $KUBECONFIG (token valid for $DURATION)"
echo "Info: To revoke access, delete the ServiceAccount: kubectl delete sa $NAME -n default"
