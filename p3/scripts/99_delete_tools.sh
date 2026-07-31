#!/bin/bash
set -e

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

# which docker
echo "Uninstall: Docker..."
uninstall_docker
echo "- docker has been removed."

# which k3d
echo "Uninstall: k3d..."
sudo rm "$(which k3d)" 2>/dev/null || true
echo "- k3d has been removed."

# which kubectl
echo "Uninstall: kubectl..."
sudo rm "$(which kubectl)" 2>/dev/null || true
echo "- kubectl has been removed."
