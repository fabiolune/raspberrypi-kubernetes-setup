# Kubernetes setup on a raspberry pi cluster

## Why

There are many resources that can help you setting up a kubernetes cluster on a Raspberry Pi, but many of them only focus on some specific aspects.
The idea of this repo is to try to collect all the aspects of a decent kubernetes setup for a Raspberry Pi, from dedicated considerations on the ARM architecture, to some basic networking aspects of a home made cluster.

## What

This repo contains instructions for the setup of a kubernetes cluster on a raspberry pi(s) based on:

- [k3s](https://k3s.io/): a lightweight kubernetes distribution
- [nginx ingress controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager](https://cert-manager.io/) to manage tls certificates generation

The plan is to extend this list to include tools for monitoring, logging and other functionalities.

## Initial setup

To work with kubernetes we will need some cli tools to interact with our clusters.
Some of them are:

- _kubectl_
- _helm_

A fantastic way to install different clis is provided by [arkade](https://github.com/alexellis/arkade), a tool created by Alex Ellis, the founder of [OpenFaas](https://www.openfaas.com/).
To install `arkade` simply run:

```console
curl -sLS https://dl.get-arkade.dev | sudo sh
```

When _arkade_ setup is done, to install _kubectl_ and _helm_ you simply need to run:

```console
ark get kubectl
ark get helm
```
> ark is a handy alias of _arkade_ 

## Setting up k3s

The easiest way to install k3s is to run the following command:
```console
curl -sfL https://get.k3s.io | sh -
```

This will create your master node, setup a `systemd` service, create a kubectl configuration file and some shell scripts that can be used to stop it and/or uninstall it.
Nevertheless, this simple setup also deploys the default ingress controller (_Traefik_), but since I decided to go with _nginx_, it is possible to change the setup command in:

```console
curl -sfL https://get.k3s.io | sh -s - --no-deploy traefik
```
> full documentation for the setup options of a master node is available [here](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/)

Now you can check that the cluster is up and running using kubectl, but first you have to retrieve the config file to connect to the cluster.

This file is automatically generated by the k3s setup and is located in `/etc/rancher/k3s/k3s.yaml`; a simple way to use it is to copy the file in your local `.kube` directory and define the `KUBECONFIG` environment variable:

```console
sudo cp /etc/rancher/k3s/k3s.yaml ${HOME}/.kube/k3s-config
export KUBECONFIG=${HOME}/.kube/k3s-config
```

To verify that your cluster is up and running, now you can run:

```console
$ kubectl get node

NAME           STATUS   ROLES    AGE   VERSION
raspberrypi    Ready    master   12s   v1.19.5+k3s2
```

## Install Nginx Ingress controller

The Nginx ingress controller provides a way to manage the incoming traffic using nginx as a reverse proxy.

To install the ingress controller the best reference to follow is available at the official website, in particular I will follow the helm approach described [here](https://kubernetes.github.io/ingress-nginx/deploy/#using-helm).

The documentation describes some peculiarities of the bare metal setup that I suggest to read [here](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/); the main points are related to:

- having a service for the controller of type __NodePort__ instead of __LoadBalancer__ (usually automatically provided by the cloud provider for managed clusters like AKS, EKS, ...)
- making sure that the _nginx_ controller is only deployed on a single node (the one that will be exposed to the internet traffic through the router port forwarding)

To ensure the second point first of all we need to tag the node in such a way that it will be the selected by the kubernetes scheduler for the _nginx_ controller pods. Assuming a name `raspberrypi` for the node (which coincide with the hostname), then you can execute the following command:

```console
kubectl label nodes raspberrypi external-exposed=true
```

Now we can move on with the ingress controller setup.

The first step is to add the _nginx_ helm repo and update helm:

```console
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Now you are ready to install the helm chart with this set of additional values:

```console
controller:
  nodeSelector:
    external-exposed: "true"
  service:
    nodePorts:
      http: 30080
      https: 30443
    type: NodePort
    externalTrafficPolicy: Local
defaultBackend:
  enabled: true
  image:
    repository: k8s.gcr.io/defaultbackend-arm
```

The command to run (assuming the above file is called `ingress.custom-values.yaml`) is simply:

```console
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -f ingress-custom-values.yaml
```

The approach with explicit `--set`values doesn't work because of the way the selector for the node gets written.

With this set of values the ingress controller will be deployed on the kubernetes cluster, the controller pods will be scheduled on the node labeled with `external-exposed=true`, will be exposed with a service of type __NodePort__ on the ports 30080 (http) and 30443 (https), will preserve the source IP thanks to the `externalTrafficPolicy` and will have a default backend with a dedicated arm image (the default backend image is not multi architecture, a specific tag is required) for all the requests that do not match any ingress definition.

To check the availability of the ingress controller you should see something similar to:

```console
$ kubectl get pod

NAME                                            READY   STATUS    RESTARTS   AGE
ingress-nginx-defaultbackend-6b59ff499f-5dhjx   1/1     Running   0          15s
ingress-nginx-controller-f5b8f5b4-s6q6z         1/1     Running   0          15s
```

Now, since no ingress resources are defined for any backend, every http request (to the node port 30080 as defined in the helm deploy) to the ingress entry-point will return a 404 (except `/healthz`). The request `curl -i http://localhost:30080/whatever`will give something like:

```console
HTTP/1.1 404 Not Found
Date: Thu, 07 Jan 2021 22:43:44 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 21
Connection: keep-alive

default backend - 404
```

The same is also true for https requests on the port 30443 (now we need to accept insecure connections with `-k` because we did not provide any tls certificate) of the form `curl -ik https://localhost:30443/whatever`

## Install cert manager

Cert manager is a tool that simplifies the operations required to generate a tls certificate for a specific domain name. Clearly you need to have a domain name first, and for this you have some options/possibilities:

- if your ISP provider gives you a static ip you can register a domain name and bind it to your ip
- if you don't have a static ip, you can rely on a dynamic DNS service (see [here](https://en.wikipedia.org/wiki/Dynamic_DNS) for further details): most modern modems give you the possibility to automatically update the DNS resolution at every ip change (these services often offer a free plan to be manually renewed every month)

The cert manager setup is done directly following the approach suggested in the official [documentation](https://cert-manager.io/docs/).

First we need a dedicated namespace:

```console
kubectl create ns cert-manager
```

Then we need to add the cert manager helm repository:

```console
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

Finally we can deploy it:

```console
helm upgrade --install cert-manager jetstack/cert-manager \
	--namespace cert-manager \
	--version v1.1.0 \
	--set installCRDs=true \
	--wait
```

> the `--wait` option helps having the resources ready for the next steps

To be able to generate ACME certificates with _Let's Encrypt_, we need to have a __ClusterIssuer__ (or issuer, the difference is that an Issuer is bound to a namespace) resource on the cluster (see full documentation [here](https://cert-manager.io/docs/concepts/issuer/)).

_Let's Encrypt_ offers, together with the production apis to request certificates (based on HTTP01 or DNS challenges) also staging apis to validate the workflow without having to worry too much about aggressive rate limits.

To simplify the delivery of both _Let's Encrypt_ __ClusterIssuers__ and additional certificate request resources (see [here](https://cert-manager.io/docs/usage/certificate/)), you can deploy the two provided helm charts:

- `letsencrypt-cluster-issuers`:

  ```console
  helm upgrade --install letsencrypt-cluster-issuers ./letsencrypt-cluster-issuers \
    --set email=<email used for ACME registration> \
    --wait
  ```

- certificate-request:

  ```console
  helm upgrade --install certificate-request certificate-request \
    --set tls.hostname=<DNS name for which you request a certificate> \
    --set clusterIssuer.type=<prod|stag letsencrypt issuer> \
    --set tls.secret.prefix=<prefix for the secret that will store the generated certificate> \
    --wait
  ```

These last steps will create both the staging and production __ClusterIssuers__ for _Lest's Encrypt_, together with the certificate request for the DNS name associated to the public ip of your cluster.

This setup is based on an HTTP-01 challenge (entirely managed by cert manager), but you need to ensure that you cluster can be reached using the dns on the standard port 80 (see the _Let's Encrypt_ [documentation](https://letsencrypt.org/docs/challenge-types/#http-01-challenge))

## Wrapping everything up

All the instructions described here can be executed launching the `setup-master.sh` script:

```console
./setup-master.sh \
  -e <your email for certificate requests> \
  -n <your domain name> \
  -p prod
```

> the `-p` option refers to the prod or stag _Let's Encrypt_ issuer

## Setup a worker node

What has been described so far is the setup of a kubernetes cluster consisting of only 1 master node. _k3s_ offers an easy way to add an additional worker node to the cluster, still based on the same installer.

First of all we need to retrieve the token created for the master node: this can be found by simply running, on the master node:

```console
sudo cat /var/lib/rancher/k3s/server/node-token
```

This token will allow the worker node to join the cluster thanks to the command (to be executed on the worker node):

```console
curl -sfL https://get.k3s.io | K3S_URL=<url of the cluster> K3S_TOKEN=<node token obtained from master node> sh -s -
```

By default, all the raspberry pis have the same hostname (`raspberrypi`), and this can generate some confusion during the setup: you can follow one of these approaches:

- change the hostname of the worker node; the best approach in my opinion because it also allows for better identification of the pi in your network
- use the `--node-name`option for k3s setup
- use the `--with-node-id`option for k3s setup

When the worker setup is complete, from the master node it is possible to verify that the worker node has been added with

```console
$ kubectl get node -o wide

NAME           STATUS   ROLES    AGE    VERSION
raspberrypi    Ready    master   151m   v1.19.5+k3s2
raspberrypi2   Ready    <none>   42s    v1.19.5+k3s2
```

In some k3s versions the role of the worker node is not defined ("<none>"); to fix that it is possible to run:

```console
kubectl label node <name of the worker node> node-role.kubernetes.io/worker=worker
```

## Further readings

- <https://blog.alexellis.io/test-drive-k3s-on-raspberry-pi/>
- <https://dev.to/sr229/how-to-use-nginx-ingress-controller-in-k3s-2ck2>
- <https://opensource.com/article/20/3/ssl-letsencrypt-k3s>