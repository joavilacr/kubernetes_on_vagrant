# kubernetes_on_vagrant
Deploy Kubernetes cluster (1 control plane and 3 worker nodes) on bento/ubuntu-18.04 servers using vagrant 


# Requirements:

## Vagrant 
vagrant --version
Version: 2.2.10

## Virtualbox
vboxmanage --version
5.2.20r125813

## Kubernetes
Using version 1.20.1-00 for kubelet, kubeadm, kubectl

Running with Containerd

## Additionals
It using Zscaler certificate to connect without problems to the internet. In case you dont have Zscaler proxy installed, please comment lines 27 and 54 in the Vagrantfile and lines 8 and 9 within scripts/plante-node.sh and scripts/nodes.sh


