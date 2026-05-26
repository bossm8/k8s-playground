#!/bin/bash

VALUES_PATH=./infrastructure/networking/cni/values
INSTALL_VERSION=1.19.4

function deploy() {
  helm upgrade --install \
      cilium \
      oci://quay.io/cilium/charts/cilium \
        --version ${INSTALL_VERSION} \
        --namespace cilium-system \
        --create-namespace \
        $PROMETHEUS_FLAGS \
        $K8S_ARGS \
        --values ${VALUES_PATH}/install.yml
}

for arg in "$@"; do
  case $arg in
    --with-prometheus)
      echo "Info: Installing with prometheus monitoring enabled (Note: use only when prometheus CRDs have been installed)"
      PROMETHEUS_FLAGS="--values ${VALUES_PATH}/flux.yml"
      shift
      ;;
    --kind)
      echo "Installing Locally"
      K8S_ARGS="
        --set k8sServiceHost=$(docker inspect k8s-playground-control-plane -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
        --set k8sServicePort=6443
      "
      shift
      ;;
  esac
done

deploy

if test -z "$PROMETHEUS_FLAGS"; then
  echo "Info: Installed without prometheus support, rerun this script with '--with-prometheus' once prometheus CRDs have been installed"
fi