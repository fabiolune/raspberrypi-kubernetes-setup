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
export KUBECONFIG=$HOME/.kube/k3s-config

# tag master node
kubectl label nodes $(hostname) external-exposed=true

# Add helm repo for nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# install nginx ingress controller with helm and custom values
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	--set controller.nodeSelector.external-exposed="true" \
	--set controller.service.type=NodePort \
	--set controller.service.nodePorts.http=30080 \
	--set controller.service.nodePorts.https=30443 \
	--set controller.service.externalTrafficPolicy=Local \
	--set defaultBackend.enabled=true \
	--set defaultBackend.image.repository=k8s.gcr.io/defaultbackend-arm