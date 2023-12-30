#!/bin/bash

sudo kubeadm init phase certs etcd-ca

export HOST0=$1
export HOST1=$2
sudo kubeadm init phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
sudo kubeadm init phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
sudo kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
sudo kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
sudo cp -R /etc/kubernetes/pki /tmp/${HOST1}/
sudo find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

sudo kubeadm init phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
sudo kubeadm init phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
sudo kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
sudo kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
# No need to move the certs because they are for HOST0

# clean up certs that should not be copied off this host
sudo find /tmp/${HOST1} -name ca.key -type f -delete

sudo chmod -R 755 /tmp/$2/pki/

# Copy config from etcd1 to etcd2
scp -o StrictHostKeyChecking=no -r /tmp/$2/* vagrant@$2:

# init etcd on etcd1
sudo kubeadm init phase etcd local --config=/tmp/$1/kubeadmcfg.yaml
