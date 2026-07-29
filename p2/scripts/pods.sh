#!/bin/bash

echo ">>> Install nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
sleep 40

echo ">>> Applying application manifests..."
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml

echo ">>> Pods script finished."