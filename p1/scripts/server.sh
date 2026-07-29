#!/bin/bash

SERVER_IP="192.168.56.110"
TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"

apt-get update -qq && apt-get install -y -qq curl bash

echo ">>> Installing K3s in server mode..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --node-ip ${SERVER_IP} \
    --tls-san ${SERVER_IP} \
    --advertise-address ${SERVER_IP}

echo ">>> Waiting for K3s server to be ready..."
until kubectl get nodes 2>/dev/null | grep -qw "Ready"; do
    sleep 3
done

echo ">>> Saving node token..."
cat "${TOKEN_FILE}" > /vagrant/node-token

echo ">>> K3s server ready."
