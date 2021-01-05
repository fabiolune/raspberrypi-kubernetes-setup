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
