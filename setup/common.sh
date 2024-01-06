#!/bin/bash

# swapoff
sudo swapoff -a
sudo sed -i 's/^.*swap/#&/' /etc/fstab

# install tree lib
sudo apt-get install tree

# Add Kernel Parameters
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure kernel parameters
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install the Docker packages
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


# add a signing key in you on Ubuntu
sudo apt update
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Add Software Repositories: Kubernetes is not included in the default repositories. To add them, enter the following
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

# Configure containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Install Kubeadm
sudo apt update   
sudo apt install -y kubeadm

# update kubelet with ip
echo "KUBELET_EXTRA_ARGS=--node-ip=$1" | sudo tee /etc/default/kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart containerd

# sudo systemctl restart containerd.service # if [systemctl restart containerd] not work
# sudo rm /etc/containerd/config.toml
# sudo systemctl restart containerd

