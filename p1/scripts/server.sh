#!/bin/bash

SERVER_IP="192.168.56.110"
TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"

set -euo pipefail

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
apt-get update && apt-get install -y curl bash

echo ">>> Installing K3s in server mode..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --node-ip "${SERVER_IP}" \
    --tls-san "${SERVER_IP}"

echo ">>> Waiting for K3s server to be ready..."
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    echo "  ... still waiting"
    sleep 5
done

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sed -i "s/127.0.0.1/${SERVER_IP}/g" /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo ">>> Saving node token..."
cat "${TOKEN_FILE}" > /vagrant/node-token

echo ">>> K3s server ready. Node token saved to /vagrant/node-token"
kubectl get nodes -o wide
