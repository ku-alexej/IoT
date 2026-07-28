#!/bin/bash

set -euo pipefail

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
TOKEN_FILE="/vagrant/node-token"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

sudo apt-get update
sudo apt-get install -y curl bash net-tools

sudo swapon --show

echo ">>> Adding /sbin and /usr/sbin to PATH..."
for home in /home/vagrant /root; do
    if ! grep -q '/sbin' "${home}/.bashrc" 2>/dev/null; then
        echo 'export PATH="$PATH:/sbin:/usr/sbin"' | sudo tee -a "${home}/.bashrc" > /dev/null
    fi
done
sudo chown vagrant:vagrant /home/vagrant/.bashrc
export PATH="$PATH:/sbin:/usr/sbin"
echo ">>> PATH updated: ${PATH}"

echo ">>> Waiting for server token..."
until [ -f "${TOKEN_FILE}" ]; do
    echo "  ... token not yet available, waiting 5s"
    sleep 5
done
echo ">>> Token found."

echo ">>> Installing config files..."
sudo mkdir -p /etc/rancher/k3s
sudo cp "${CONFIG_DIR}/kubelet-swap-config.yaml" /etc/rancher/k3s/kubelet-swap-config.yaml
sed -e "s/__SERVER_IP__/${SERVER_IP}/g" \
    -e "s/__WORKER_IP__/${WORKER_IP}/g" \
    "${CONFIG_DIR}/k3s-agent-config.yaml" | sudo tee /etc/rancher/k3s/config.yaml > /dev/null
echo ">>> Config files installed."

echo ">>> Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - agent
echo ">>> K3s installed and running."
