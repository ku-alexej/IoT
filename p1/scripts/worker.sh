#!/bin/bash

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
TOKEN_FILE="/vagrant/node-token"

apt-get update -qq && apt-get install -y -qq curl bash net-tools

echo ">>> Waiting for server token..."
until [ -f "${TOKEN_FILE}" ]; do
    sleep 3
done

# TOKEN=$(cat "${TOKEN_FILE}")
echo ">>> Token found. Installing K3s agent..."
curl -sfL https://get.k3s.io | sh -s - agent \
    --server "https://${SERVER_IP}:6443" \
    --node-ip "${WORKER_IP}" \
    --token-file "${TOKEN_FILE}"

echo ">>> K3s agent ready."