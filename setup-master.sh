#!/bin/sh

# Install arkade
curl -sLS https://dl.get-arkade.dev | sudo sh

# Install kubectl and helm
ark get kubectl
ark get helm

# add ark folder to PATH
export PATH=$PATH:$HOME/.arkade/bin/

# Install k3s without trafik (the default ingress controller)
curl -sfL https://get.k3s.io | sh -s - --no-deploy traefik

# copy generated kube config into default folder
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
export KUBECONFIG=${HOME}/.kube/k3s-config