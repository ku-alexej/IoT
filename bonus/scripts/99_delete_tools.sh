#!/bin/bash
set -e

# ==============================
# LIBRARY
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# UNINSTALL
# ==============================

uninstall_docker() {

    # Remove docker elments
    if command -v docker >/dev/null 2>&1; then
        {
            docker rm -f $(docker ps -aq) || true
            docker volume rm $(docker volume ls -q) || true
            docker network prune -f || true
            docker image prune -af || true
        } >/dev/null 2>&1
    fi

    # Stop Docker services
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl stop docker docker.socket containerd 2>/dev/null || true
        sudo systemctl disable docker docker.socket containerd 2>/dev/null || true
    fi

    # Kill dockerd if it was started manually
    sudo pkill -f dockerd 2>/dev/null || true

    # Remove Docker packages
    sudo apt-get remove -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras \
        docker.io \
        containerd \
        runc >/dev/null 2>&1 || true

    sudo apt-get autoremove -y >/dev/null 2>&1 || true

    # Remove Docker data
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    sudo rm -rf /var/lib/containerd 2>/dev/null || true

    # Remove Docker configuration
    sudo rm -rf /etc/docker 2>/dev/null || true
    sudo rm -f /var/run/docker.sock 2>/dev/null || true
}

# ==============================
# MAIN
# ==============================

title "Deleting Tools"
printf "\n"

log_warning "docker" "uninstalling"
uninstall_docker
log_success "docker" "has been removed"
printf "\n"

log_warning "k3d" "uninstalling"
sudo rm "$(which k3d)" 2>/dev/null || true
log_success "k3d" "has been removed"
printf "\n"

log_warning "kubectl" "uninstalling"
sudo rm "$(which kubectl)" 2>/dev/null || true
log_success "kubectl" "has been removed"
printf "\n"

log_warning "helm" "uninstalling"
sudo rm "$(which helm)" 2>/dev/null || true
log_success "helm" "has been removed"

title "Done"
printf "\n"
