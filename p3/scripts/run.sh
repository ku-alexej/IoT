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

readonly GIT_USER="ku-alexej"
readonly GIT_DIR="akurochk-Inception-of-Things"
readonly GIT_MAIL="akurochk@student.42.fr"

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_REPO="${HOME}/${GIT_DIR}"


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
    printf "\n[%s/9] %s:\n" "$number" "$text"
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

log_error() {
    status "$1" "$2" "$RED"
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
            log_error "$tool" "not installed"
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

    log_warning "docker" "not ready"
    if command -v systemctl >/dev/null 2>&1; then
        log_warning "docker" "starting"
        sudo systemctl enable --now docker >/dev/null 2>&1
    fi

    for _ in $(seq 1 20); do
        log_warning "docker" "waiting"
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
        log_error "$1" "missing"
        exit 1
    fi
}

# ==============================
# SETUPS
# ==============================

create_cluster() {
    local cluster="$1"
    shift
    if k3d cluster get "$cluster" >/dev/null 2>&1; then
        # log_error "$cluster" "already exists"
        # exit 1
        # for debug
        log_warning "$cluster" "deleting old one"
        bash ./99_delete_cluster.sh >/dev/null # for debug
    fi
    log_warning "$cluster" "creating"
    if k3d cluster create "$cluster" --image rancher/k3s:v1.32.5-k3s1 "$@" >/dev/null; then
        log_success "$cluster" "created"
    else
        log_error "$cluster" "creation failed"
        exit 1
    fi
}

install_argocd() {
    log_warning "argocd" "installing"

    kubectl apply \
        --server-side \
        --force-conflicts \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml \
        -n argocd \
        >/dev/null

    log_warning "argocd" "waiting"

    kubectl wait \
        --for=condition=available \
        --timeout=300s deployment/argocd-server \
        -n argocd \
        >/dev/null

    log_success argocd "installed"
}

# ==============================
# MAIN
# ==============================

title "Setup script was started"

log_step 1 "Check tools"
if ! check_tools; then
    log_error "tools" "missing one or more tools"
    exit 1
fi

log_step 2 "Check docker"
if ! check_docker; then
    log_error "docker" "uavailable"
    exit 1
fi

log_step 3 "Create k3d cluster"
create_cluster ${CLUSTER_NAME} \
    -p "8888:30042@loadbalancer" \
    --wait

log_step 4 "Create namespaces"
kubectl apply -f ../confs/00_namespaces.yaml >/dev/null
for ns in "${NAMESPACES[@]}"; do
    check_namespace "$ns"
done

log_step 5 "Install ArgoCD"
install_argocd
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

log_step 6 "Prepare manifest v1"
rm -rf ${DIR_REPO}
log_warning "git" "cloning git@github.com:${GIT_USER}/${GIT_DIR}.git"
git clone "git@github.com:${GIT_USER}/${GIT_DIR}.git" "$DIR_REPO" >/dev/null 2>&1

log_warning "git" "configure local repo"
cd "$DIR_REPO"
git config --local user.name "$GIT_USER"
git config --local user.email "$GIT_EMAIL"
cp "${DIR_SCRIPT}/../confs/01_deployment.yaml" "${DIR_REPO}/deployment.yaml"

git add deployment.yaml
if ! git diff --cached --quiet; then
    log_warning "git" "update manifest"
    git commit -m "chore: update deployment manifest (v1)" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1
fi
log_success "git" "manifest prepared"

log_step 7 "Setup ArgoCD"
kubectl apply -f "${DIR_SCRIPT}/../confs/02_argocd.yaml" >/dev/null
log_success "argocd" "yaml applyed"

log_step 8 "Forward ports for ArgoCD"
pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
nohup kubectl port-forward \
    -n argocd svc/argocd-server \
    4242:443 \
    --address 0.0.0.0 \
    >/tmp/argocd.log 2>&1 &
sleep 2
log_success "ports" "ready"

log_step 9 "Wait for app answer"
for _ in $(seq 1 30); do
    if curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
        log_success "app" "ready"
        break
    fi
    log_warning "app" "waiting"
    sleep 2
done
if ! curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
    log_error "app" "timeout"
    exit 1
fi

title "Installation complited"
printf "Wil app      : http://localhost:8888\n"
printf "Argo CD      : http://localhost:4242\n"
printf "  - login    : admin\n"
printf "  - password : ${ARGOCD_PASS}\n\n"
