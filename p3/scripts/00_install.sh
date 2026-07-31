#!/bin/bash
set -e

install_curl() {
    echo "Install: curl..."
    sudo apt-get install -y -qq curl
}

install_docker() {
    echo "Install: docker..."
    curl -fsSL https://get.docker.com | sh &>/dev/null
    sudo usermod -aG docker "$USER"
}

install_kubectl() {
    echo "Install: kubectl..."
    curl -sLO https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl
    chmod 0755 ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
}

install_k3d() {
    echo "Install: k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash &>/dev/null
}

install_git() {
    echo "Install: git..."
    sudo apt-get install -y -qq git
}

echo -e "\nStart tools installation\n"

# docker
echo "Check:   curl..."
command -v curl &>/dev/null || install_curl
echo -e "Done:    curl\n"


# docker
echo "Check:   docker..."
command -v docker &>/dev/null || install_docker
echo -e "Done:    docker\n"

# kubectl
echo "Check:   kubectl..."
command -v kubectl &>/dev/null || install_kubectl
echo -e "Done:    kubectl\n"

# k3d
echo "Check:   k3d..."
command -v k3d &>/dev/null || install_k3d
echo -e "Done:    k3d\n"

# git
echo "Check:   git..."
command -v git &>/dev/null || install_git
echo -e "Done:    git\n"

# ArgoCD
# - must be installed inside cluster

# end
echo "All tools installed"
# echo -e "Relog to apply group permissions\n"