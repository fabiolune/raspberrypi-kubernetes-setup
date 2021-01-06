# Why

There are many resources that can help you setting up a kubernetes cluster on a Raspberry Pi, but many of them only focus on some specific aspects.
The idea of this repo is to try to collect all the aspects of a decent kubernetes setup for a Raspberry Pi, from dedicated considerations on the ARM architecture, to some basic networking aspects of a home made cluster.

# What

This repo contains the bare minimum components to have a kubernetes cluster up & running on my raspberry pi(s).

The minimal setup is based on:
- [k3s](https://k3s.io/): a lightweight kubernetes distribution
- [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager](https://cert-manager.io/)

The plan is to extend this list to include tools for monitoring, logging and other functionalities.

## Setting up k3s

The easiest way to install k3s is to run the following command:
```console
curl -sfL https://get.k3s.io | sh -
```

This will create your master node, setup a systemctl service, create a kubectl configuration file and some shell scripts that can be used to stop it and/or uninstall it.
Nevertheless, this simple setup also deploys the default ingress controller (traefik), but since I decided to go with nginx, it is possible to change the setup command in:

```console
curl -sfL https://get.k3s.io | sh -s - --no-deploy traefik
```
> full documentation for the setup options of a master node is available [here](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/)

