#!/bin/bash

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
TOKEN_FILE="/vagrant/node-token"

set -euo pipefail

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
apt-get update && apt-get install -y curl bash net-tools


echo ">>> Waiting for server token..."
until [ -f "${TOKEN_FILE}" ]; do
    echo "  ... token not yet available, waiting 5s"
    sleep 5
done

TOKEN=$(cat "${TOKEN_FILE}")
echo ">>> Token found. Installing K3s agent..."

curl -sfL https://get.k3s.io | sh -s - agent \
    --server "https://${SERVER_IP}:6443" \
    --token "${TOKEN}" \
    --node-ip "${WORKER_IP}" \
    --flannel-iface eth1

echo ">>> K3s agent installed and running."
