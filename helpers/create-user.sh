#!/bin/bash

USER=$1
TALOS_MC=$2

if test -z ""$USER""; then
  echo "Username argument is required"
  exit 1
fi

if test -z "$TALOS_MC"; then
  echo "Talos controlplane machineconfig path is required (must include secrets)"
  exit 1
fi

if ! which yq; then
  echo "yq is required to use this script"
  exit 1
fi

CA_CRT="$(cat $TALOS_MC | yq -r '.cluster.ca.crt' | base64 -d)"
CA_KEY="$(cat $TALOS_MC | yq -r '.cluster.ca.key' | base64 -d)"

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

export KUBECONFIG=./"$USER"-kubeconfig

CLUSTERNAME="$(cat $TALOS_MC | yq -r '.cluster.clusterName')"

kubectl config set-cluster "$CLUSTERNAME" \
  --server=$(cat $TALOS_MC | yq -r '.cluster.controlPlane.endpoint') \
  --certificate-authority=<(echo "$CA_CRT") \
  --embed-certs=true
kubectl config set-credentials "$USER" \
  --client-certificate="$USER".crt \
  --client-key="$USER".key \
  --embed-certs=true
kubectl config set-context default \
  --cluster="$CLUSTERNAME" \
  --user="$USER"
kubectl config use-context default

rm -rf "$USER".*