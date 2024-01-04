#!/bin/bash

# Initialize Kubernetes on Master Node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$1

# Start cluster
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy Pod Network to Cluster
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
