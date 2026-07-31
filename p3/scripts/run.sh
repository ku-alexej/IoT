#!/bin/bash
set -e

# check all tools
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
WB='\033[1;37m'
NC='\033[0m'

are_tools_ready() {
    printf "[1/142] SETUP check tools:\n"
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

is_docker_ready() {
    printf "[2/142] SETUP check docker status:\n"

    if docker info >/dev/null 2>&1; then
        printf "     - docker    : ${G}ready${NC}\n\n"
        return 0
    fi

    printf "     - docker    : ${R}not ready${NC}\n"
    if command -v systemctl >/dev/null 2>&1; then
        printf "     - docker    : ${Y}starting${NC}\n"
        sudo systemctl enable --now docker >/dev/null 2>&1
    fi

    for _ in $(seq 1 20); do
        printf "     - docker    : ${Y}...${NC}\n" 
        if docker info >/dev/null 2>&1; then
            printf "     - docker    : ${G}ready${NC}\n\n"
            return 0
        fi
        sleep 1
    done

    return 1
}

printf "\n${WB}=== Start SETUP script ===${NC}\n\n"

if ! are_tools_ready; then
    printf "${R}One of tools is not installed.${NC}\n\n"
    exit 1
fi

if ! is_docker_ready; then
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
k3d cluster create p3-cluster \
    --wait

if k3d cluster list | grep -qw "p3-cluster"; then
    printf "     - %-10s : ${G}installed${NC}\n\n" "p3-cluster"
else
    printf "${R}Cluster \"p3-cluster\" was not created.${NC}\n\n"
    exit 1
fi

printf "[4/142] SETUP define namespaces:\n"


# END setup
#     - final message
#     - how to use
