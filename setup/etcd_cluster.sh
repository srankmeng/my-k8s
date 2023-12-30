#!/bin/bash

echo "===== Initial etcd cluster ====="

# Copy config from etcd1 to etcd2
sudo scp -o StrictHostKeyChecking=no -r /tmp/$2/* vagrant@$2:

# init etcd on etcd1
kubeadm init phase etcd local --config=/tmp/$1/kubeadmcfg.yaml
