#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================
# LIBRARY
# ==============================

source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# SETUPS
# ==============================

deploying_gitlab() {

    log_warning "gitlab" "deploying to k3d"

    helm repo add gitlab https://charts.gitlab.io/ >/dev/null
    helm repo update >/dev/null

    helm install gitlab gitlab/gitlab \
        --version 9.11.8 \
        --values https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml \
        --set global.hosts.domain=akurochk.com \
        --set global.hosts.externalIP=0.0.0.0 \
        --set global.hosts.https=false \
        --set global.ingress.enabled=false \
        --set certmanager-issuer.email="admin@gitlab.akurochk.com" \
        --timeout 900s \
        -n gitlab \
        >/dev/null

    log_success "gitlab" "deployed"
}

waiting_gitlab() {

    log_warning "gitlab" "waiting for the gitlab (around 5 min)"

    SECONDS=0
    sleep 30

    kubectl wait \
        --for=condition=Ready \
        pods \
        -l app=webservice \
        --timeout=1200s \
        -n gitlab \
        >/dev/null

    local elapsed=$SECONDS
    local m=$((elapsed / 60))
    local s=$((elapsed % 60))

    log_success "gitlab" "$(printf 'ready (took %02dm %02ds)' "$m" "$s")"
}

# ==============================
# MAIN
# ==============================

deploying_gitlab
waiting_gitlab
