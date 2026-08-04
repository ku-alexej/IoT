#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================

readonly CLUSTER_NAME="bonus-cluster"
readonly NAMESPACES=("dev" "argocd" "gitlab")
readonly TOOLS=("curl" "docker" "kubectl" "k3d" "git" "helm")
readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    if k3d cluster create "$cluster" -p "8888:30042@loadbalancer" --wait >/dev/null; then
        log_success "$cluster" "cluster created"
    else
        log_error_exit "$cluster" "failed to create cluster"
    fi
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

    log_warning "argocd" "starting port-forward"
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
    nohup kubectl port-forward \
        -n argocd svc/argocd-server \
        4242:443 \
        --address 0.0.0.0 \
        >/tmp/argocd.log 2>&1 &
    sleep 2

    log_success "argocd" "ready"
}

waiting_app() {

    for _ in $(seq 1 30); do
        if curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
            log_success "app" "application is ready"
            break
        fi
        log_warning "app" "waiting for application"
        sleep 2
    done

    if ! curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
        log_error_exit "app" "timed out"
    fi
}

install_gitlab() {

    log_warning "gitlab" "adding oficial helm repository"
    helm repo add gitlab https://charts.gitlab.io/ >/dev/null || true
    log_warning "gitlab" "------------------------------"
    helm repo update >/dev/null

    log_warning "gitlab" "installing gitlab"

    local ip=$(curl -s ifconfig.me 2>/dev/null ||  echo "127.0.0.1")
    log_warning "gitlab" "------------------------------"
    if ! helm list -n gitlab 2>/dev/null | grep -q "gitlab"; then
        log_warning "gitlab" "------------------------------"
        helm install gitlab gitlab/gitlab \
            --namespace gitlab \
            --timeout 900s \
            --set global.hosts.externalIP=$ip \
            --set gitlab.webservice.puma.workers=0 \
            -f "${DIR_SCRIPT}/../confs/03_gitlab.yaml" \
            >/dev/null
    fi

    log_warning "gitlab" "waiting... (you have time for a cup of coffe)"
    if kubectl rollout status deployment/gitlab-webservice-default \
        -n gitlab --timeout=900s >/dev/null 2>&1; then
        log_success "gitlab" "is ready"
    else
        log_error_exit "gitlab" "timed out waiting for webservice"
    fi
}

# ==============================
# MAIN
# ==============================

bash ./98_*
bash ./99_*
bash ./00_*

title "Starting installation"

log_step 1 8 "Checking tools"
if ! check_tools; then
    log_error_exit "tools" "missing one or more tools"
fi

log_step 2 8 "Checking Docker"
if ! check_docker; then
    log_error_exit "docker" "unavailable"
fi

log_step 3 8 "Creating k3d cluster"
create_cluster ${CLUSTER_NAME}

log_step 4 8 "Creating namespaces"
kubectl apply -f ${DIR_SCRIPT}/../confs/00_namespaces.yaml >/dev/null
for ns in "${NAMESPACES[@]}"; do
    check_namespace "$ns"
done

log_step 5 8 "Install GitLab"
install_gitlab

log_step 6 8 "Installing Argo CD"
install_argocd
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

log_step 7 8 "Configuring Argo CD"
configure_argocd

log_step 8 8 "Wait for application to become ready"
waiting_app

title "Setup completed successfully"
printf "\nApplication  : http://localhost:8888\n"
printf "Argo CD UI   : http://localhost:4242\n\n"
printf "Credentials\n"
printf "  - Username : admin\n"
printf "  - Password : ${ARGOCD_PASS}\n\n"
