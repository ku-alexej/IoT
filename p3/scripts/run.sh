#!/bin/bash
set -e

# check all tools
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
WB='\033[1;37m'
NC='\033[0m'

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

check_namespaces() {
    if kubectl get ns "$1" >/dev/null 2>&1; then
        printf "     - %-10s : ${G}created${NC}\n" "$1"
    else
        printf "${R}Namespace \"%s\" was not created.${NC}\n\n" "$1"
        exit 1
    fi
}

create_cluster() {
    local cluster="$1"
    if k3d cluster get "$cluster" >/dev/null 2>&1; then
        # printf "${R}Cluster \"%s\" already exists.${NC}\n\n" "$cluster"
        # exit 1

        # for debug
        printf "     - %-10s : ${Y}old cluster deleting...${NC}\n" "$cluster"
        bash ./99_delete_cluster.sh >/dev/null # for debug
    fi
    printf "     - %-10s : ${Y}creating...${NC}\n" "$cluster"
    if k3d cluster create "$cluster" --wait >/dev/null; then
        printf "     - %-10s : ${G}created${NC}\n\n" "$cluster"
    else
        printf "${R}Cluster \"%s\" was not created.${NC}\n\n" "$cluster"
        exit 1
    fi
}

printf "\n${WB}=== Start SETUP script ===${NC}\n\n"

printf "[1/142] SETUP check tools:\n"
if ! check_tools; then
    printf "${R}One of tools is not installed.${NC}\n\n"
    exit 1
fi

printf "[2/142] SETUP check docker status:\n"
if ! check_docker; then
    printf "${R}Docker is not running.${NC}\n\n"
    exit 1
fi

# START setup
#     - setup : create cluster with k3d
#     - setup : define namespaces
#     - setup : install AgroCD inside cluster
#     - setup : prepare manifest
#     - setup : push manifest to Git
#     - setup : apply ArgoCD app
#     - setup : forward ports for ArgoCD
#     - setup : wait for app answer

printf "[3/142] SETUP create cluster with k3d:\n"
create_cluster "p3-cluster"

printf "[4/142] SETUP define namespaces:\n"
kubectl apply -f ../confs/00_namespaces.yaml >/dev/null
for ns in dev argocd; do
    check_namespaces "$ns"
done


# END setup
#     - final message
#     - how to use
