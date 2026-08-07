#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================

readonly CLUSTER_NAME="bonus-cluster"
readonly NAMESPACES=("dev" "argocd" "gitlab")
readonly TOOLS=("curl" "docker" "kubectl" "k3d" "git" "helm")
readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WIL_HOST="wil.akurochk.com"
readonly ARGOCD_HOST="argocd.akurochk.com"
readonly GITLAB_HOST="gitlab.akurochk.com"

# ==============================
# LIBRARY
# ==============================

source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# CHECKS
# ==============================

check_tools() {
    local ret=0

    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool" "installed"
        else
            log_warning "$tool" "not installed"
            ret=1
        fi
    done

    return "$ret"
}

check_docker() {

    if docker info >/dev/null 2>&1; then
        log_success "docker" "ready"
        return 0
    fi

    log_warning "docker" "not running"
    if command -v systemctl >/dev/null 2>&1; then
        log_warning "docker" "starting service"
        sudo systemctl enable --now docker >/dev/null 2>&1
    fi

    for _ in $(seq 1 20); do
        log_warning "docker" "waiting for startup"
        if docker info >/dev/null 2>&1; then
            log_success "docker" "ready"
            return 0
        fi
        sleep 1
    done

    return 1
}

check_namespace() {

    if kubectl get ns "$1" >/dev/null 2>&1; then
        log_success "$1" "created"
    else
        log_error_exit "$1" "missing"
    fi
}

# ==============================
# SETUPS
# ==============================

create_cluster() {
    local cluster="$1"
    shift

    if k3d cluster get "$cluster" >/dev/null 2>&1; then
        log_error_exit "$cluster" "already exists"
    fi

    log_warning "$cluster" "creating cluster"
    if k3d cluster create "$cluster" -p "80:80@loadbalancer" -p "443:443@loadbalancer" --wait >/dev/null; then
        log_success "$cluster" "cluster created"
    else
        log_error_exit "$cluster" "failed to create cluster"
    fi
}

configure_hosts() {

    local entry
    for entry in "$WIL_HOST" "$ARGOCD_HOST" "$GITLAB_HOST"; do
        if grep -qE "[[:space:]]${entry}(\$|[[:space:]])" /etc/hosts 2>/dev/null; then
            log_success "$entry" "already in /etc/hosts"
        else
            log_warning "$entry" "adding to /etc/hosts"
            echo "127.0.0.1 ${entry}" | sudo tee -a /etc/hosts >/dev/null
            log_success "$entry" "added to /etc/hosts"
        fi
    done
}

install_argocd() {

    log_warning "argocd" "deploying"
    kubectl apply \
        --server-side \
        --force-conflicts \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml \
        -n argocd \
        >/dev/null

    log_warning "argocd" "waiting for deployment"
    kubectl wait \
        --for=condition=available \
        --timeout=300s deployment/argocd-server \
        -n argocd \
        >/dev/null

    log_success argocd "deployed"
}

configure_argocd() {

    log_warning "argocd" "applying configuration"
    kubectl apply -f "${DIR_SCRIPT}/../confs/02_argocd.yaml" >/dev/null

    log_warning "ingress" "applying wil / argocd / gitlab rules"
    kubectl apply -f "${DIR_SCRIPT}/../confs/03_ingress.yaml" >/dev/null

    log_warning "argocd" "switching to insecure (HTTP) mode for ingress"
    kubectl rollout restart deployment/argocd-server -n argocd >/dev/null
    kubectl rollout status deployment/argocd-server -n argocd --timeout=120s >/dev/null

    log_success "argocd" "ready"
}

waiting_app() {

    for _ in $(seq 1 30); do
        if curl -fsS -H "Host: ${WIL_HOST}" http://localhost/ 2>/dev/null | grep -q '"v1"'; then
            log_success "app" "application is ready"
            break
        fi
        log_warning "app" "waiting for application"
        sleep 2
    done

    if ! curl -fsS -H "Host: ${WIL_HOST}" http://localhost/ 2>/dev/null | grep -q '"v1"'; then
        log_error_exit "app" "timed out"
    fi
}

# ==============================
# MAIN
# ==============================

# cleaning for debug
bash ./98_*
bash ./99_*
bash ./00_*

title "Starting installation"

log_step 1 10 "Checking tools"
if ! check_tools; then
    log_error_exit "tools" "missing one or more tools"
fi

log_step 2 10 "Checking Docker"
if ! check_docker; then
    log_error_exit "docker" "unavailable"
fi

log_step 3 10 "Creating k3d cluster"
create_cluster ${CLUSTER_NAME}

log_step 4 10 "Configuring /etc/hosts"
configure_hosts

log_step 5 10 "Creating namespaces"
kubectl apply -f ${DIR_SCRIPT}/../confs/00_namespaces.yaml >/dev/null
for ns in "${NAMESPACES[@]}"; do
    check_namespace "$ns"
done

# ------ Start of GitLab block ------


log_step 6 10 "GitLab"
bash ./01_gitlab.sh

log_step 7 10 "Manifest v1"
bash ./01_manifest_v1.sh

# ------ End of GitLab block ------

log_step 8 10 "Installing Argo CD"
install_argocd

log_step 9 10 "Configuring Argo CD"
configure_argocd

log_step 10 10 "Wait for application to become ready"
waiting_app

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode)

title "Setup completed successfully"

printf "\nApplication  : http://%s\n\n" "${WIL_HOST}"

printf "Argo CD UI   : http://%s\n" "${ARGOCD_HOST}"
printf "  - Username : admin\n"
printf "  - Password : ${ARGOCD_PASS}\n\n"

printf "GitLab       : http://%s\n" "${GITLAB_HOST}"
printf "  - Username : root\n"
printf "  - Password : ${GITLAB_PASS}\n\n"
