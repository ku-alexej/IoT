#!/bin/bash

set -euo pipefail

SERVER_IP="192.168.56.110"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

sudo apt-get update
sudo apt-get install curl -y

sudo swapon --show

echo ">>> Installing config files..."
sudo mkdir -p /etc/rancher/k3s
sudo cp "${CONFIG_DIR}/kubelet-swap-config.yaml" /etc/rancher/k3s/kubelet-swap-config.yaml
sed "s/__IP_SERVER__/${SERVER_IP}/g" "${CONFIG_DIR}/k3s-config.yaml" | \
    sudo tee /etc/rancher/k3s/config.yaml > /dev/null
echo ">>> Config files installed."

# k3s reads /etc/rancher/k3s/config.yaml automatically, no CLI flags needed
echo ">>> Installing K3s ..."
curl -sfL https://get.k3s.io | sh -
echo ">>> Waiting for K3s server to be ready..."
until curl -sk https://127.0.0.1:6443/healthz > /dev/null 2>&1; do
    echo "    ... waiting"
    sleep 5
done
echo ">>> K3s installed and running."

# Install kubectl and configure kubeconfig for both the vagrant user and root
echo ">>> Setup kubectl..."
curl -sLO https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
sudo mkdir -p /home/vagrant/.kube /root/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
#sudo sed -i "s/127.0.0.1/${SERVER_IP}/g" /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
cp /home/vagrant/.kube/config /root/.kube/config
echo ">>> Kubectl is ready"

# Alias "k" for kubectl, with bash completion, for vagrant and root users
echo ">>> Setup alias k=kubectl..."
for home in /home/vagrant /root; do
    if ! grep -q "alias k=kubectl" "${home}/.bashrc" 2>/dev/null; then
        cat <<'EOF' | sudo tee -a "${home}/.bashrc" > /dev/null

# kubectl alias
alias k=kubectl
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
EOF
    fi
done
sudo chown vagrant:vagrant /home/vagrant/.bashrc
echo ">>> Alias k is ready"
