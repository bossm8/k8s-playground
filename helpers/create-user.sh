#!/bin/bash

# This script generates a new user with default namespace creation
# permissions in the cluster

USER=$1

function usage() {
  echo "Usage: /bin/bash create-user.sh <username>"
  echo "  username:     name for the user to create (chars: a-z and -)"
}

if test -z "$USER" || ! [[ "$USER" =~ ^[a-z]+$ ]]; then
  echo "Error: Valid username argument is required (allowed chars: a-z)"
  usage && exit 1
fi

if ! which kubectl; then
  echo "Error: kubectl is required to use this script"
  exit 1
fi

openssl ecparam -name secp256r1 -genkey -noout -out $1.key
openssl ec -in "$USER".key -pubout > "$USER".pub
openssl req -new -key "$USER".key -out "$USER".csr -subj "/CN=$1"

# https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/certificate-signing-request-v1/

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: "$USER"
spec:
  request: $(cat "$USER".csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages:
    - client auth
EOF

sleep 5
kubectl certificate approve "$USER"
sleep 5
kubectl get csr "$USER" -o jsonpath='{ .status.certificate }'| base64 -d > "$USER".crt
kubectl delete csr "$USER"

echo "Assigning RBAC to allow creation of namespaces to $USER"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: namespace-creator:"$USER"
  labels:
    app.kubernetes.io/component: user-playground
    app.kubernetes.io/managed-by: create-user.sh
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: "$USER"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-creator
EOF

export KUBECONFIG=./"$USER"-kubeconfig

CLUSTERNAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

kubectl config set-cluster "$CLUSTERNAME" \
  --server="$SERVER" \
  --certificate-authority=<(echo "$CA_DATA" | base64 -d) \
  --embed-certs=true
kubectl config set-credentials "$USER" \
  --client-certificate="$USER".crt \
  --client-key="$USER".key \
  --embed-certs=true
kubectl config set-context default \
  --cluster="$CLUSTERNAME" \
  --user="$USER"
kubectl config use-context default

# Cleanup generated resources
rm -rf "$USER".*

echo "Info: Kubeconfig written to $KUBECONFIG"
