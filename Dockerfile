# https://github.com/argoproj/argo-cd/blob/master/Dockerfile
#
# docker build --pull -t foobar .
# docker run --rm -ti             --entrypoint bash foobar
# docker run --rm -ti --user root --entrypoint bash foobar

ARG BASE_IMAGE=docker.io/library/ubuntu:24.04

FROM $BASE_IMAGE

LABEL org.opencontainers.image.source https://github.com/ajaykumar4/home-lab-argocd

ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "I am running on final $BUILDPLATFORM, building for $TARGETPLATFORM"

# binary versions
ARG AGE_VERSION="v1.1.1"
ARG JQ_VERSION="1.6"
ARG HELM_VERSION="v3.14.4"
ARG HELMFILE_VERSION="0.163.1"
ARG KUSTOMIZE_VERSION="5.1.1"
ARG SOPS_VERSION="v3.8.1"
ARG YQ_VERSION="v4.35.1"
ARG CURL_VERSION="v8.7.1"

# relevant for kubectl if installed
ARG KUBESEAL_VERSION="0.24.5"
ARG KUBECTL_VERSION="v1.29.2"

# plugin versions
ARG HELM_DIFF_VERSION="v3.9.5"
ARG HELM_GIT_VERSION="v0.3.0"
ARG HELM_SECRETS_VERSION="v4.6.0"

RUN mkdir -p custom-tools/helm-plugins
WORKDIR /custom-tools

RUN \
    GO_ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/') && \
    wget -qO-                          "https://get.helm.sh/helm-${HELM_VERSION}-linux-${GO_ARCH}.tar.gz" | tar zxv --strip-components=1 -C /tmp linux-${GO_ARCH}/helm && mv /tmp/helm /custom-tools/helm && \
    wget -qO "/custom-tools/sops"      "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${GO_ARCH}" && \
    wget -qO-                          "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-${GO_ARCH}.tar.gz" | tar zxv --strip-components=1 -C /custom-tools age/age age/age-keygen && \
    wget -qO-                          "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${GO_ARCH}.tar.gz" | tar zxv -C /custom-tools helmfile && \
    wget -qO "/custom-tools/jq"        "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${GO_ARCH}" && \
    wget -qO "/custom-tools/yq"        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${GO_ARCH}" && \
    wget -qO "/custom-tools/curl"      "https://github.com/moparisthebest/static-curl/releases/download/${CURL_VERSION}/curl-$(uname -m)" && \
    wget -qO "/custom-tools/kubectl"   "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${GO_ARCH}/kubectl" && \
    wget -qO-                          "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${GO_ARCH}.tar.gz" | tar zxv -C /custom-tools kustomize && \
    wget -qO-                          "https://github.com/jkroepke/helm-secrets/releases/download/${HELM_SECRETS_VERSION}/helm-secrets.tar.gz" | tar -C /custom-tools/helm-plugins -xzf-; && \
    wget -qO-                          "https://github.com/databus23/helm-diff/releases/download/${HELM_DIFF_VERSION}/helm-diff-linux-${GO_ARCH}.tgz" | tar -C /custom-tools/helm-plugins -xzf-; && \
    wget -qO-                          "https://github.com/aslafy-z/helm-git/archive/refs/tags/${HELM_GIT_VERSION}.tar.gz" | tar -C /custom-tools/helm-plugins -xzf-; && \
    true

RUN cp /custom-tools/helm-plugins/helm-secrets/scripts/wrapper/helm.sh /custom-tools/helm && \
    chmod +x /custom-tools/* && \
    true
