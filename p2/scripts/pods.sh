#!/bin/bash

echo ">>> Waiting for Traefik ingress controller (K3s default)..."
until kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik 2>/dev/null | grep -q "1/1.*Running"; do
    sleep 3
done

echo ">>> Applying application manifests..."
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo ">>> Pods script finished."