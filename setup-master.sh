#!/bin/sh

while getopts ":n:p:e:" opt; do
  case $opt in
    n) host="$OPTARG"
    secretPrefix=$(echo $host | sed s/\\./-/g)
    ;;
    p) if [ $OPTARG = 'prod' ]; then type=prod; fi
    ;;
    e) email="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done
if [ "$type" = '' ]
then
  type=stag
fi

echo "\nThis will install the following components:"
echo " - k3s"
echo " - nginx ingress controller (using helm chart)"

if [ "$host" != '' ] && [ "$secretPrefix" != '' ] && [ "$email" != '' ]
then
  echo " - cert manager (using helm chart with '$type' Let's Encrypt ClusterIssuer)"
fi

echo ""

while [ "$ans" != 'y' ] && [ "$ans" != 'n' ]
do
  read -p "Do you want to continue? [y/n] " ans
done

if [ "$ans" = 'n' ]
then
  exit 0
fi

echo "Install arkade\n"

# Install arkade
curl -sLS https://dl.get-arkade.dev | sudo sh

echo "Install kubectl\n"
ark get kubectl

echo "Install helm\n"
ark get helm

# add ark folder to PATH
export PATH=$PATH:$HOME/.arkade/bin/

# Install k3s without traefik, the default ingress controller (because we want to install nginx as ingress controller)
echo "Install k3s\n"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.19.5+k3s2 sh -s - --no-deploy traefik --node-name $(hostname)

# copy generated kube config into default folder
mkdir -p ~/.kube
sudo \cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chmod +rw ~/.kube/config

# adding a cutom made timeout for retrieveing the node
# the native timeout command doesn't seem to be able to properly run the while loop depending on the node variable
limit=$((`date +%s`+300))
while [ "`date +%s`" -lt $limit ] && [ "$node" = "" ]
  do
    node=`kubectl get node | awk /$(hostname)/'{print $1}'`
done

# if the script times out, i.e. the cluster is not ready after 30 secs, stop here
if [ "$node" = "" ]
then
  echo "[ERROR] It seems that there is an error while connecting to the cluster."
  exit 1
fi

# tag master node
kubectl label nodes $(hostname) external-exposed=true

# Add helm repo for nginx
echo "Deploy nginx\n"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# install nginx ingress controller with helm and custom values
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -f ingress-custom-values.yaml

# create cert-manager namespace
echo "Deploy cert manager and related resources\n"
# configure jetstack helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl create namespace cert-manager 2>/dev/null

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.1.0 \
  --set installCRDs=true \
  --wait


if [ "$host" != '' ] && [ "$email" != '' ]
then
  
  echo "Install letsencrypt issuers"
  helm upgrade --install letsencrypt-cluster-issuers ./letsencrypt-cluster-issuers \
    --namespace cert-manager \
    --set email=$email \
	--wait
	
  echo "Install certificate request"
  helm upgrade --install certificate-request certificate-request \
    --set tls.hostname=$host \
    --set tls.secret.prefix=$secretPrefix \
    --set clusterIssuer.type=$type \
	--wait

fi
