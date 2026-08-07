#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================


readonly HOST_ENTRY="127.0.0.1 gitlab.bonus.akurochk.com"
readonly HOSTS_FILE="/etc/hosts"

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================
# LIBRARY
# ==============================

source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# SETUPS
# ==============================

adding_host() {

    log_warning "gitlab" "adding local host addres"
    if ! grep -q "$HOST_ENTRY" "$HOSTS_FILE"; then
        log_warning "gitlab" "adding host"
        echo "$HOST_ENTRY" | sudo tee -a "$HOSTS_FILE" >/dev/null
    fi
    log_success "gitlab" "host prepared"
}

deploying_gitlab() {

    log_warning "gitlab" "deploying to k3d"

    helm repo add gitlab https://charts.gitlab.io/ >/dev/null
    helm repo update >/dev/null

    helm install gitlab gitlab/gitlab \
        --version 9.11.8 \
        --values https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml \
        --set global.hosts.domain=bonus.akurochk.com\
        --set global.hosts.externalIP=0.0.0.0 \
        --set global.hosts.https=false \
        --set certmanager-issuer.email="admin@gitlab.bonus.com" \
        --timeout 900s \
        -n gitlab \
        >/dev/null

    log_success "gitlab" "deployed"
}

waiting_gitlab() {

    log_warning "gitlab" "waiting for the gitlab"

    kubectl wait \
        --for=condition=Ready \
        pods \
        -l app=webservice \
        --timeout=1200s \
        -n gitlab \
        >/dev/null

    log_success "gitlab" "ready"
}

print_password() {

    log_warning "gitlab" "requesting password"
    GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode)
    
    log_success "login" "root"
    log_success "password" "$GITLAB_PASSWORD"
}

port_forward() {

    kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8181 2>&1 >/dev/null &
    log_success "gitlab: http://gitlab.bonus.akurochk.com:8080"
    log_success "gitlab: http://localhost:8080"
}

# ==============================
# MAIN
# ==============================

adding_host
deploying_gitlab
waiting_gitlab
print_password
port_forward
