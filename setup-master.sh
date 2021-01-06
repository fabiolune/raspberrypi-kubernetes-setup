#!/bin/sh

# Install k3s wthout trafik (the default ingress controller)
curl -sfL https://get.k3s.io | sh -s - --no-deploy traefik

# copy generated kube config into default folder
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
echo "To connect to your local cluster you can define an env variable with"
echo "  export KUBECONFIG=${HOME}/.kube/k3s-config"
echo "or you can rename your generated config with:"
echo "  mv ${HOME}/.kube/k3s-config${HOME} ${HOME}/.kube/k3s-config"
