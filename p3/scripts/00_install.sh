#!/bin/bash
set -e

# ==============================
# COLORS
# ==============================

readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly WHITE="\033[1;37m"
readonly RESET="\033[0m"

# ==============================
# CONFIGURATION
# ==============================

readonly USERNAME="akurochk"
readonly EMAIL="akurochk@student.42.fr"

readonly GIT_USER="ku-alexej"
readonly GIT_DIR="akurochk-Inception-of-Things"

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

# ==============================
# MAIN
# ==============================

title "Installing required tools"

# docker
log_step 1 "curl"
log_warning "curl" "checking"
command -v curl &>/dev/null || install_curl
log_success "curl" "installed"

# docker
log_step 2 "docker"
log_warning "docker" "checking"
command -v docker &>/dev/null || install_docker
log_success "docker" "installed"

# kubectl
log_step 3 "kubectl"
log_warning "kubectl" "checking"
command -v kubectl &>/dev/null || install_kubectl
log_success "kubectl" "installed"

# k3d
log_step 4 "k3d"
log_warning "k3d" "checking"
command -v k3d &>/dev/null || install_k3d
log_success "k3d" "installed"

# git
log_step 5 "git"
log_warning "git" "checking"
command -v git &>/dev/null || install_git
log_success "git" "installed"

# end
title "Tool installation completed"
printf "\n"
