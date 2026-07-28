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

sleep 20

echo ">>> Setup kubectl..."
curl -sLO https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
sudo mkdir -p /home/vagrant/.kube /root/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
#sudo sed -i "s/127.0.0.1/${IP_SERVER}/g" /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
cp /home/vagrant/.kube/config /root/.kube/config

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


echo ">>> Applying application manifests"
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo ">>> Server script finished."
