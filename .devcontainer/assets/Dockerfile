ARG K8S_VERSION=1.35.2
ARG FLUX_VERSION=2.7.5
ARG BAO_VERSION=2.4.3
ARG KIND_VERSION=0.31.0
ARG DOCKER_VERSION=20.10
ARG HELM_VERSION=3.20
ARG CILIUM_CLI_VERSION=0.19.0
ARG CERTMANAGER_CLI_VERSION=1.12.17

# Hack stages since 'COPY --from' cannot expand env
FROM alpine/kubectl:${K8S_VERSION} AS kubectl
FROM fluxcd/flux-cli:v${FLUX_VERSION} AS flux
FROM openbao/openbao:${BAO_VERSION} AS bao
FROM alpine/helm:${HELM_VERSION} AS helm
FROM docker:${DOCKER_VERSION} AS docker

# ---

FROM ubuntu:latest AS curl

RUN apt-get update \
    && apt-get install -y curl

# ---

FROM curl AS kind

# Need to redefine already defined args for the stages for them to work
ARG KIND_VERSION
ARG TARGETARCH

RUN curl -LO --fail https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-${TARGETARCH}{,.sha256sum} \
    && sha256sum --check kind-linux-arm64.sha256sum \
    && install -o root -g root -m 0755 kind-linux-${TARGETARCH} /usr/local/bin/kind

# ---

FROM curl AS cilium

ARG CILIUM_CLI_VERSION
ARG TARGETARCH

RUN curl -LO --fail https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-${TARGETARCH}.tar.gz{,.sha256sum} \
    && sha256sum --check cilium-linux-${TARGETARCH}.tar.gz.sha256sum \
    && tar xzvfC cilium-linux-${TARGETARCH}.tar.gz /usr/local/bin

# ---

FROM curl AS cmctl

ARG TARGETARCH
ARG CERTMANAGER_CLI_VERSION

RUN curl -LO --fail https://github.com/cert-manager/cert-manager/releases/download/v${CERTMANAGER_CLI_VERSION}/cmctl-linux-${TARGETARCH}.tar.gz \
    && tar xzf cmctl-linux-${TARGETARCH}.tar.gz \
    && mv cmctl /usr/local/bin

# ---

FROM ubuntu:latest

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        bash-completion \
        curl \
        git \
        inotify-tools \
        make \
        python3 \
        rsync

COPY --from=kubectl /usr/local/bin/kubectl /usr/local/bin/
COPY --from=cilium /usr/local/bin/cilium /usr/local/bin/
COPY --from=docker /usr/local/bin/docker /usr/local/bin/
COPY --from=cmctl /usr/local/bin/cmctl /usr/local/bin/
COPY --from=kind /usr/local/bin/kind /usr/local/bin/
COPY --from=flux /usr/local/bin/flux /usr/local/bin/
COPY --from=helm /usr/bin/helm /usr/local/bin/
COPY --from=bao /bin/bao /usr/local/bin/

# Add bash completion scripts
RUN kind completion bash > /etc/bash_completion.d/kind \
    && flux completion bash > /etc/bash_completion.d/flux \
    && kubectl completion bash > /etc/bash_completion.d/kubectl \
    && cilium completion bash > /etc/bash_completion.d/cilium \
    && cmctl completion bash > /etc/bash_completion.d/cmctl \
    && helm completion bash > /etc/bash_completion.d/helm \
    && bao -autocomplete-install \
    && curl --fail -o /etc/bash_completion.d/docker -L \
      https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker \
    && cp /etc/skel/.bashrc /root/.bashrc \
    && mkdir -p ~/.kube \
    && curl --fail -o ~/.kube/aliases \
      https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases \
    && echo "test -f ~/.kube/aliases && source ~/.kube/aliases" >> ~/.bashrc \
    && echo "complete -F __start_kubectl k" >>~/.bashrc

ENTRYPOINT ["/bin/bash"]
