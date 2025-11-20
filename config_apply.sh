#!/bin/bash

set -euox pipefail

aws ecr describe-repositories >/dev/null || true
aws eks update-kubeconfig --region us-east-2 --name pytorch-gpu-dev-cluster
kubectl apply -f namespace.yml
kubectl config set-context --current --namespace=jean-test
kubectl delete -k . || true
kubectl apply -k .

set +euox pipefail

echo "Applied configuration to the cluster."
