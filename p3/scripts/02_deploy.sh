#!/bin/bash
set -e

# ==============================
# COLORS
# ==============================

readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly WHITE="\033[1;37m"
readonly RESET="\033[0m"

# ==============================
# CONFIGURATION
# ==============================

readonly CLUSTER_NAME="p3-cluster"
readonly NAMESPACES=("dev" "argocd")
readonly TOOLS=("curl" "docker" "kubectl" "k3d" "git")
readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================
# LOG FUNCTIONS
# ==============================

title() {
    local text=$1
    printf "\n${WHITE}>>> %s <<<${RESET}\n" "$text"
}

log_step() {
    local number=$1
    local text=$2
    printf "\n[%s/7] %s:\n" "$number" "$text"
}

status() {
    local name="$1"
    local status="$2"
    local color="$3"
    printf "     - %-10s : ${color}%s${RESET}\n" "$name" "$status"
}

log_success() {
    status "$1" "$2" "$GREEN"
}

log_warning() {
    status "$1" "$2" "$YELLOW"
}

log_error_exit() {
    status "$1" "$2" "$RED"
    echo ""
    exit 1
}

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
        # for debug
        # log_warning "$cluster" "removing existing cluster"
        # bash ./99_delete_cluster.sh >/dev/null # for debug
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

# ==============================
# MAIN
# ==============================

title "Starting installation"

log_step 1 "Checking tools"
if ! check_tools; then
    log_error_exit "tools" "missing one or more tools"
fi

log_step 2 "Checking Docker"
if ! check_docker; then
    log_error_exit "docker" "unavailable"
fi

log_step 3 "Creating k3d cluster"
create_cluster ${CLUSTER_NAME}

log_step 4 "Creating namespaces"
kubectl apply -f ../confs/00_namespaces.yaml >/dev/null
for ns in "${NAMESPACES[@]}"; do
    check_namespace "$ns"
done

log_step 5 "Installing Argo CD"
install_argocd
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

log_step 6 "Configuring Argo CD"
configure_argocd

log_step 7 "Wait for application to become ready"
waiting_app

title "Setup completed successfully"
printf "\nApplication  : http://localhost:8888\n"
printf "Argo CD UI   : http://localhost:4242\n\n"
printf "Credentials\n"
printf "  - Username : admin\n"
printf "  - Password : ${ARGOCD_PASS}\n\n"
