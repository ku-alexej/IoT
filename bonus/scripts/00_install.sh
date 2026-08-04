#!/bin/bash
set -e

# ==============================
# LIBRARY
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# SETUPS
# ==============================

install_curl() {
    log_warning "curl" "installing"
    sudo apt-get install -y -qq curl
}

install_docker() {
    log_warning "docker" "installing"
    curl -fsSL https://get.docker.com | sh &>/dev/null
    sudo usermod -aG docker "$USER"
}

install_kubectl() {
    log_warning "kubectl" "installing"
    curl -sLO https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
    chmod 0755 ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
}

install_k3d() {
    log_warning "k3d" "installing"
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash &>/dev/null
}

install_git() {
    log_warning "git" "installing"
    sudo apt-get install -y -qq git
}

install_helm() {
    log_warning "helm" "installing"
    curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash &>/dev/null
}

# ==============================
# MAIN
# ==============================

title "Installing required tools"

# docker
log_step 1 6 "curl"
log_warning "curl" "checking"
command -v curl &>/dev/null || install_curl
log_success "curl" "installed"

# docker
log_step 2 6 "docker"
log_warning "docker" "checking"
command -v docker &>/dev/null || install_docker
log_success "docker" "installed"

# kubectl
log_step 3 6 "kubectl"
log_warning "kubectl" "checking"
command -v kubectl &>/dev/null || install_kubectl
log_success "kubectl" "installed"

# k3d
log_step 4 6 "k3d"
log_warning "k3d" "checking"
command -v k3d &>/dev/null || install_k3d
log_success "k3d" "installed"

# git
log_step 5 6 "git"
log_warning "git" "checking"
command -v git &>/dev/null || install_git
log_success "git" "installed"

# helm
log_step 6 6 "helm"
log_warning "helm" "checking"
command -v helm &>/dev/null || install_helm
log_success "helm" "installed"

# end
title "Tool installation completed"
printf "\n"
