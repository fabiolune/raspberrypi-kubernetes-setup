#!/bin/sh

# Install k3s wthout trafik (the default ingress controller)
curl -sfL https://get.k3s.io | sh -s - --no-deploy traefik

# copy generated kube config into default folder
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
