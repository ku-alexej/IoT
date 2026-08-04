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
readonly NAMESPACES=("dev", "argocd")

readonly GIT_USER="ku-alexej"
readonly GIT_DIR="akurochk-Inception-of-Things"
readonly GIT_MAIL="akurochk@student.42.fr"

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_REPO="${HOME}/${GIT_DIR}"


# ==============================
# LOG FUNCTIONS
# ==============================



# ==============================
# CHECKS
# ==============================



# ==============================
# SETUPS
# ==============================



# ==============================
# MAIN LINE
# ==============================


check_tools() {
    ret=0

    for t in curl docker kubectl k3d git; do
        if ! command -v "$t" >/dev/null 2>&1; then
            printf "     - %-10s : ${RED}not installed${RESET}\n" "$t"
            ret=1
        else 
            printf "     - %-10s : ${GREEN}installed${RESET}\n" "$t"
        fi
    done

    printf "\n"

    return "$ret"
}

check_docker() {

    if docker info >/dev/null 2>&1; then
        printf "     - docker     : ${GREEN}ready${RESET}\n\n"
        return 0
    fi

    printf "     - docker     : ${RED}not ready${RESET}\n"
    if command -v systemctl >/dev/null 2>&1; then
        printf "     - docker     : ${YELLOW}starting${RESET}\n"
        sudo systemctl enable --now docker >/dev/null 2>&1
    fi

    for _ in $(seq 1 20); do
        printf "     - docker     : ${YELLOW}...${RESET}\n" 
        if docker info >/dev/null 2>&1; then
            printf "     - docker     : ${GREEN}ready${RESET}\n\n"
            return 0
        fi
        sleep 1
    done

    return 1
}

check_namespace() {
    if kubectl get ns "$1" >/dev/null 2>&1; then
        printf "     - %-10s : ${GREEN}created${RESET}\n" "$1"
    else
        printf "${RED}Namespace \"%s\" was not created.${RESET}\n\n" "$1"
        exit 1
    fi
}

create_cluster() {
    local cluster="$1"
    shift
    if k3d cluster get "$cluster" >/dev/null 2>&1; then
        printf "${RED}Cluster \"%s\" already exists.${RESET}\n\n" "$cluster"
        exit 1
        # for debug
        # printf "     - %-10s : ${YELLOW}old cluster deleting...${RESET}\n" "$cluster"
        # bash ./99_delete_cluster.sh >/dev/null # for debug
    fi
    printf "     - %-10s : ${YELLOW}creating...${RESET}\n" "$cluster"
    if k3d cluster create "$cluster" --image rancher/k3s:v1.32.5-k3s1 "$@" >/dev/null; then
        printf "     - %-10s : ${GREEN}created${RESET}\n\n" "$cluster"
    else
        printf "${RED}Cluster \"%s\" was not created.${RESET}\n\n" "$cluster"
        exit 1
    fi
}

install_argocd() {
    printf "     - %-10s : ${YELLOW}installing...${RESET}\n" "argocd"
    kubectl apply \
        --server-side \
        --force-conflicts \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml \
        -n argocd \
        >/dev/null
    printf "     - %-10s : ${YELLOW}waiting for ArgoCD...${RESET}\n" "argocd"
    kubectl wait \
        --for=condition=available \
        --timeout=300s deployment/argocd-server \
        -n argocd \
        >/dev/null
    printf "     - %-10s : ${GREEN}installed${RESET}\n" "argocd"
}

printf "\n${WHITE}=== Start SETUP script ===${RESET}\n\n"

printf "[1/10] SETUP check tools:\n"
if ! check_tools; then
    printf "${RED}One of the tools is not installed.${RESET}\n\n"
    exit 1
fi

printf "[2/10] SETUP check docker status:\n"
if ! check_docker; then
    printf "${RED}Docker is not running.${RESET}\n\n"
    exit 1
fi

printf "[3/10] SETUP create cluster with k3d:\n"
create_cluster ${CLUSTER_NAME} \
    -p "8888:30042@loadbalancer" \
    --wait

printf "[4/10] SETUP define namespaces:\n"
kubectl apply -f ../confs/00_namespaces.yaml >/dev/null
for ns in "${NAMESPACES[@]}"; do
    check_namespace "$ns"
done
printf "\n"

printf "[5/10] SETUP install ArgoCD inside cluster:\n"
install_argocd
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
printf "\n"

printf "[6/10] SETUP prepare manifest:\n"



rm -rf ${DIR_REPO}
printf "     - %-10s : ${YELLOW}cloning git@github.com:${GIT_USER}/${GIT_DIR}.git${RESET}\n" "git"
git clone "git@github.com:${GIT_USER}/${GIT_DIR}.git" "$DIR_REPO" >/dev/null 2>&1

printf "     - %-10s : ${YELLOW}go to local repo...${RESET}\n" "git"
cd "$DIR_REPO"
printf "     - %-10s : ${YELLOW}configure local repo...${RESET}\n" "git"
git config --local user.name "$GIT_USER"
git config --local user.email "$GIT_EMAIL"
cp "${DIR_SCRIPT}/../confs/01_deployment.yaml" "${DIR_REPO}/deployment.yaml"

git add deployment.yaml
if ! git diff --cached --quiet; then
    printf "     - %-10s : ${YELLOW}update manifest...${RESET}\n" "git"
    git commit -m "chore: update deployment manifest (v1)" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1
fi
printf "     - %-10s : ${GREEN}manifest prepared${RESET}\n\n" "git"

printf "[7/10] SETUP apply ArgoCD app:\n"
kubectl apply -f "${DIR_SCRIPT}/../confs/02_argocd.yaml"
printf "     - %-10s : ${GREEN}yaml applyed${RESET}\n\n" "argocd"

printf "[8/10] SETUP forward ports for ArgoCD:\n"
pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
nohup kubectl port-forward \
    -n argocd svc/argocd-server \
    4242:443 \
    --address 0.0.0.0 \
    >/tmp/argocd.log 2>&1 &
sleep 2
printf "     - %-10s : ${GREEN}done${RESET}\n\n" "ports for Argo CD"

printf "[9/10] SETUP wait for app answer:\n"
for _ in $(seq 1 10); do
    if curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
        printf "     - %-10s : ${GREEN}aplication is ready${RESET}\n\n" "app"
        break
    fi
    printf "     - %-10s : ${YELLOW}waiting...${RESET}\n" "app"
    sleep 2
done
if ! curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"v1"'; then
    printf "${RED}App is still not responding.${RESET}\n\n"
    exit 1
fi

printf "[10/10] SETUP ${GREEN}done${RESET}:\n"
printf "Wil app      : http://localhost:8888\n"
printf "Argo CD      : http://localhost:4242\n"
printf "  - login    : admin\n"
printf "  - password : ${ARGOCD_PASS}\n"

