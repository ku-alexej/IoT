#!/bin/bash
set -e

# check all tools
R="\033[0;31m"
G="\033[0;32m"
Y="\033[0;33m"
WB="\033[1;37m"
NC="\033[0m"


check_tools() {
    ret=0

    for t in curl docker kubectl k3d git; do
        if ! command -v "$t" >/dev/null 2>&1; then
            printf "     - %-10s : ${R}not installed${NC}\n" "$t"
            ret=1
        else 
            printf "     - %-10s : ${G}installed${NC}\n" "$t"
        fi
    done

    printf "\n"

    return "$ret"
}

check_docker() {

    if docker info >/dev/null 2>&1; then
        printf "     - docker     : ${G}ready${NC}\n\n"
        return 0
    fi

    printf "     - docker     : ${R}not ready${NC}\n"
    if command -v systemctl >/dev/null 2>&1; then
        printf "     - docker     : ${Y}starting${NC}\n"
        sudo systemctl enable --now docker >/dev/null 2>&1
    fi

    for _ in $(seq 1 20); do
        printf "     - docker     : ${Y}...${NC}\n" 
        if docker info >/dev/null 2>&1; then
            printf "     - docker     : ${G}ready${NC}\n\n"
            return 0
        fi
        sleep 1
    done

    return 1
}

check_namespace() {
    if kubectl get ns "$1" >/dev/null 2>&1; then
        printf "     - %-10s : ${G}created${NC}\n" "$1"
    else
        printf "${R}Namespace \"%s\" was not created.${NC}\n\n" "$1"
        exit 1
    fi
}

create_cluster() {
    local cluster="$1"
    shift
    if k3d cluster get "$cluster" >/dev/null 2>&1; then
        # printf "${R}Cluster \"%s\" already exists.${NC}\n\n" "$cluster"
        # exit 1

        # for debug
        printf "     - %-10s : ${Y}old cluster deleting...${NC}\n" "$cluster"
        bash ./99_delete_cluster.sh >/dev/null # for debug
    fi
    printf "     - %-10s : ${Y}creating...${NC}\n" "$cluster"
    if k3d cluster create "$cluster" "$@" >/dev/null; then
        printf "     - %-10s : ${G}created${NC}\n\n" "$cluster"
    else
        printf "${R}Cluster \"%s\" was not created.${NC}\n\n" "$cluster"
        exit 1
    fi
}

install_argocd() {
    printf "     - %-10s : ${Y}installing...${NC}\n" "argocd"
    kubectl apply \
        --server-side \
        --force-conflicts \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml \
        -n argocd \
        >/dev/null
    printf "     - %-10s : ${Y}waiting for ArgoCD...${NC}\n" "argocd"
    kubectl wait \
        --for=condition=available \
        --timeout=300s deployment/argocd-server \
        -n argocd \
        >/dev/null
    printf "     - %-10s : ${G}installed${NC}\n" "argocd"
}

printf "\n${WB}=== Start SETUP script ===${NC}\n\n"

printf "[1/10] SETUP check tools:\n"
if ! check_tools; then
    printf "${R}One of the tools is not installed.${NC}\n\n"
    exit 1
fi

printf "[2/10] SETUP check docker status:\n"
if ! check_docker; then
    printf "${R}Docker is not running.${NC}\n\n"
    exit 1
fi

# START setup
#     - setup : create cluster with k3d
#     - setup : define namespaces
#     - setup : install ArgoCD inside cluster
#     - setup : prepare manifest
#     - setup : push manifest to Git
#     - setup : apply ArgoCD app
#     - setup : forward ports for ArgoCD
#     - setup : wait for app answer

printf "[3/10] SETUP create cluster with k3d:\n"
create_cluster "p3-cluster" \
    -p "4242:443@loadbalancer" \
    -p "8888:30042@loadbalancer" \
    --wait

printf "[4/10] SETUP define namespaces:\n"
kubectl apply -f ../confs/00_namespaces.yaml >/dev/null
for ns in dev argocd; do
    check_namespace "$ns"
done
printf "\n"

printf "[5/10] SETUP install ArgoCD inside cluster:\n"
install_argocd
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
# printf "Pass : ${ARGOCD_PASS}\n"
printf "\n"

printf "[6/10] SETUP prepare manifest:\n"
GIT_USER="ku-alexej"
GIT_DIR="akurochk-Inception-of-Things"
GIT_EMAIL="akurochk@student.42.fr"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${HOME}/${GIT_DIR}"
if [ ! -d "$REPO_DIR" ]; then
    printf "     - %-10s : ${Y}cloning git@github.com:${GIT_USER}/${GIT_DIR}.git${NC}\n" "git"
    git clone "git@github.com:${GIT_USER}/${GIT_DIR}.git" "$REPO_DIR" >/dev/null 2>&1
fi
printf "     - %-10s : ${Y}go to local repo...${NC}\n" "git"
cd "$REPO_DIR"
printf "     - %-10s : ${Y}configure local repo...${NC}\n" "git"
git config --local user.name "$GIT_USER"
git config --local user.email "$GIT_EMAIL"
cp "${SCRIPT_DIR}/../confs/01_dev.yaml" "${REPO_DIR}/deployment.yaml"

git add deployment.yaml
if ! git diff --cached --quiet; then
    printf "     - %-10s : ${Y}update manifest...${NC}\n" "git"
    git commit -m "chore: update deployment manifest (v1)" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1
fi
printf "     - %-10s : ${G}manifest prepared${NC}\n\n" "git"

printf "[7/10] SETUP apply ArgoCD app:\n"
kubectl apply -f "${SCRIPT_DIR}/../confs/02_argocd.yaml"
printf "     - %-10s : ${G}yaml applyed${NC}\n\n" "argocd"

# printf "[8/10] SETUP forward ports for ArgoCD:\n"

printf "[9/10] SETUP wait for app answer:\n"
for _ in $(seq 1 10); do
    if curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"message":"v1"'; then
        printf "     - %-10s : ${G}aplication is ready${NC}\n\n" "app"
        break
    fi
    printf "     - %-10s : ${Y}waiting...${NC}\n" "app"
    sleep 2
done


# if ! curl -fsS http://localhost:8888/ 2>/dev/null | grep -q '"message":"v1"'; then
#     printf "${R}App is still not responding.${NC}\n\n"
#     exit 1
# fi

printf "[10/10] SETUP ${G}done${NC}:\n"
IFCONFIG_IP=$(curl -s ifconfig.me)
printf "Wil app      : http://${IFCONFIG_IP}:8888\n"
printf "Argo CD      : http://${IFCONFIG_IP}:8080\n"
printf "  - login    : admin\n"
printf "  - password : ${ARGOCD_PASS}\n"

