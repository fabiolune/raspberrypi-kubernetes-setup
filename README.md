# Why

There are many resources that can help you setting up a kubernetes cluster on a Raspberry Pi, but many of them only focus on some specific aspects.
The idea of this repo is to try to collect all the aspects of a decent kubernetes setup for a Raspberry Pi, from dedicated considerations on the ARM architecture, to some basic networking aspects of a home made cluster.

# What

This repo contains the bare minimum components to have a kubernetes cluster up & running on my raspberry pi(s).

The minimal setup is based on:
- [k3s](https://k3s.io/): a lightweight kubernetes distribution
- [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager](https://cert-manager.io/) to manage tls certificates generation

The plan is to extend this list to include tools for monitoring, logging and other functionalities.

## Initial setup

To work with kubernetes we will need some cli tools to interact with our clusters.
Some of them are:
- kubectl
- helm

A fantastic way to install different clis is provided by [arkade](https://github.com/alexellis/arkade), a tool created by Alex Ellis.
To install `arkade` simply run:

```console
curl -sLS https://dl.get-arkade.dev | sudo sh
```

When arkade setup is done, to install kubectl and helm you simply need to run:

```console
ark get kubectl
ark get helm
```
> ark is a handy alias of arkade

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

To verify that your cluster is up and running, now you can run:

```console
kubectl get node
```

The output of the command should be something like:

```console
NAME           STATUS   ROLES    AGE   VERSION
raspberrypi    Ready    master   12s   v1.19.5+k3s2
```



## Install Nginx Ingress controller

The Nginx ingress controller provides a way to manage the incoming traffic using nginx as a reverse proxy.

To install the ingress controller the best reference to follow is available at the official website[^1], in particular I will follow the helm approach described [here](https://kubernetes.github.io/ingress-nginx/deploy/#using-helm).

The documentation describes some peculiarities of the bare metal setup that I suggest to read [here](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/); the main points are related to:

- having a service for the controller of type __NodePort__ instead of __LoadBalancer__ (usually automatically provided by the cloud provider for managed clusters like AKS, EKS, ...)
- making sure that the nginx controller is only deployed on a single node (the one that will be exposed to the internet traffic through the router port forwarding)

To ensure the second point first of all we need to tag the node in such a way that it will be the selected by the kubernetes scheduler for the nginx controller pods. Assuming a name `raspberrypi` for the node (which coincide with the hostname), then you can execute the following command:

```console
kubectl label nodes raspberrypi external-exposed=true
```

Now we can move on with the ingress controller setup.

The first step is to add the nginx helm repo and update helm:

```console
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Now you are ready to install the helm chart with the following command:

```console
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	--set controller.nodeSelector.external-exposed="true" \
	--set controller.service.type=NodePort \
	--set controller.service.nodePorts.http=30080 \
	--set controller.service.nodePorts.https=30443 \
	--set controller.service.externalTrafficPolicy=Local \
	--set defaultBackend.enabled=true \
	--set defaultBackend.image.repository=k8s.gcr.io/defaultbackend-arm
```

With this set of values the ingress controller will be deployed on the kubernetes cluster, the controller pods will be scheduled on the node labeled with `external-exposed=true`, will be exposed with a service of type NodePort on the ports 30080 (http) and 30443 (https), will preserve the source IP thanks to the `externalTrafficPolicy` and will have a default backend with a dedicated arm image for all the requests that do not match any ingress definition.

To check the availability of the ingress controller:

```console
kubectl get pod
```

The output should be something similar to:

```console
NAME                                            READY   STATUS    RESTARTS   AGE
ingress-nginx-defaultbackend-6b59ff499f-5dhjx   1/1     Running   0          15s
ingress-nginx-controller-f5b8f5b4-s6q6z         1/1     Running   0          15s
```

Now, since no ingress resources are defined for any backend, every http request (to the node port 30080 as defined in the helm deploy) to the ingress entrypoint will return a 404 (except `/healthz`). The request `curl -i http://localhost:30080/whatever`will give something like:

```console
HTTP/1.1 404 Not Found
Date: Thu, 07 Jan 2021 22:43:44 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 21
Connection: keep-alive

default backend - 404
```

The same is also true for https requests on the port 30443 (now we need to accept insecure connections with `-k` because we did not provide any tls certificate) of the form `curl -ik https://localhost:30443/whatever`











---

[^1]:https://kubernetes.github.io/ingress-nginx/deploy