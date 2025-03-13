#!/bin/bash

function prereq() {
  helm repo add cilium https://helm.cilium.io/
  helm repo update
}

function deploy() {
  helm upgrade --install \
      cilium \
      cilium/cilium \
        --version 1.17.1 \
        --namespace kube-system \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
        --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --set k8sServiceHost=localhost \
        --set k8sServicePort=7445 \
        --set hostFirewall.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.relay.enabled=true \
        --set hubble.tls.auto.method=cronJob \
        $PROMETHEUS_FLAGS \
        --set operator.replicas=1
}

for arg in "$@"; do
  case $arg in
    --with-prometheus)
      echo "Info: Installing with prometheus monitoring enabled (Note: use only when prometheus CRDs have been installed)"
      PROMETHEUS_FLAGS='
        --set prometheus.enabled=true
        --set prometheus.serviceMonitor.enabled=true
        --set serviceMonitor.enabled=true
        --set dashboards.enabled=true
        --set dashboards.annotations.grafana_folder=Cilium
        --set hubble.metrics.enabled={dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}
        --set hubble.metrics.enableOpenMetrics=true
        --set hubble.metrics.serviceMonitor.enabled=true
        --set hubble.metrics.dashboards.enabled=true
        --set hubble.metrics.dashboards.annotations.grafana_folder=Cilium/Hubble
        --set hubble.relay.prometheus.enabled=true
        --set hubble.relay.prometheus.serviceMonitor.enabled=true
        --set envoy.prometheus.enabled=true
        --set envoy.prometheus.serviceMonitor.enabled=true
        --set operator.prometheus.enabled=true
        --set operator.prometheus.serviceMonitor.enabled=true
        --set operator.dashboards.enabled=true
        --set operator.dashboards.annotations.grafana_folder=Cilium/Operator
      '
      shift
      ;;
  esac
done

prereq
deploy

if test -z "$PROMETHEUS_FLAGS"; then
  echo "Info: Installed without prometheus support, rerun this script with '--with-prometheus' once prometheus CRDs have been installed"
fi