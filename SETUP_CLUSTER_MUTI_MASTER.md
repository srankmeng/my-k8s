## Step การติดตั้ง Kubernetes cluster (2 Master node, 2 Worker nodes, 1 Load balancer)
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ  node ทั้ง Master, Worker node และ Load Balancer
* สร้าง Load balancer
* สร้าง Master node และ Cluster
* สร้าง Worker node และทำการ join เข้า Cluster


## 1. ติดตั้ง Docker บน Ubuntu
* [Reference](https://docs.docker.com/engine/install/ubuntu/)

รันเพื่อทดสอบว่าใช้ได้ 

```
$ sudo docker version

Client: Docker Engine - Community
 Version:           20.10.14
 API version:       1.41
 Go version:        go1.16.15
 Git commit:        a224086
 Built:             Thu Mar 24 01:48:02 2022
 OS/Arch:           linux/amd64
 Context:           default
 Experimental:      true

Server: Docker Engine - Community
 Engine:
  Version:          20.10.14
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.16.15
  Git commit:       87a90dc
  Built:            Thu Mar 24 01:45:53 2022
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.5.11
  GitCommit:        3df54a852345ae127d1fa3092b95168e4a88e2f8
 runc:
  Version:          1.0.3
  GitCommit:        v1.0.3-0-gf46b6ba
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

ถ้าเจอข้อความประมานนี้
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

ให้รัน command เพื่อเปิดใช้งาน docker
```
sudo systemctl enable docker
sudo systemctl start docker
```

## 2. ติดตั้ง Kubernetes บน Ubuntu


ปิดการใช้งาน swap 
```
sudo swapoff -a
```

ปิดการใช้งาน swap ถาวรแม้จะเปิดปิดเครื่องใหม่
```
sudo nano /etc/fstab
```

จากนั้น comment code บรรทัดที่เป็น swap
```
#/swap.img  none    swap    sw  0    0 
```

Enter the following to add a signing key in you on Ubuntu
```
sudo apt update

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

Add Software Repositories: Kubernetes is not included in the default repositories. To add them, enter the following
```
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
```

Install Kubeadm
```
sudo apt update   
sudo apt install -y kubeadm
```

Check
```
kubeadm --help
kubectl --help
kubelet --help
```

## 3. สร้าง Load balancer

### Installing cfssl
CFSSL is an SSL tool by Cloudflare which lets us create our Certs and CAs.

Download the binaries
```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
```

Add the execution permission to the binaries
```
chmod +x cfssl*
```

Move the binaries to `/usr/local/bin`
```
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

Verify the installation
```
cfssl version
```

### Installing HAProxy Load Balancer

ไปที่ Load Balancer node

Install HAProxy
```
sudo apt-get install haproxy
```

Configure HAProxy
```
sudo nano /etc/haproxy/haproxy.cfg
```

Enter the following config:
```
global
...
default
...
frontend kubernetes
bind <LOAD_BALANCER_IP>:6443
option tcplog
mode tcp
default_backend kubernetes-master-nodes


backend kubernetes-master-nodes
mode tcp
balance roundrobin
option tcp-check
server k8s-master-a <MASTER_1_IP>:6443 check fall 3 rise 2
server k8s-master-b <MASTER_2_IP>:6443 check fall 3 rise 2
server k8s-master-c <MASTER_3_IP>:6443 check fall 3 rise 2
```
replace `<LOAD_BALANCER_IP>`, `<MASTER_1_IP>`, `<MASTER_2_IP>`, `<MASTER_3_IP>` depend on nodes ip

Restart HAProxy
```
sudo systemctl restart haproxy
```

Check status
```
systemctl status haproxy
```

### Generating the TLS certificates
These steps can be done on your Linux client if you have one or on the HAProxy machine depending on where you installed the cfssl tool.

Create the certificate authority configuration file
```
nano ca-config.json
```

Enter the following config:
```
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
```

Create the certificate authority signing request configuration file
```
nano ca-csr.json
```

Enter the following config, Change the names as necessary:
```
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IN",
    "L": "Belgaum",
    "O": "Tansanrao",
    "OU": "CA",
    "ST": "Karnataka"
  }
 ]
}
```

Generate the certificate authority certificate and private key
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Verify that the ca-key.pem and the ca.pem were generated
```
ls -la
```

### Creating the certificate for the Etcd cluster
Create the certificate signing request configuration file
```
nano kubernetes-csr.json
```

Add the following config:
```
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IN",
    "L": "Belgaum",
    "O": "Tansanrao",
    "OU": "CA",
    "ST": "Karnataka"
  }
 ]
}
```

Generate the certificate and private key
```
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-hostname=<LOAD_BALANCER_IP>,<MASTER_1_IP>,<MASTER_2_IP>,<MASTER_3_IP>,127.0.0.1,kubernetes.default \
-profile=kubernetes kubernetes-csr.json | \
cfssljson -bare kubernetes
```
replace `<LOAD_BALANCER_IP>`, `<MASTER_1_IP>`, `<MASTER_2_IP>`, `<MASTER_3_IP>` depend on nodes ip

Verify that the kubernetes-key.pem and the kubernetes.pem file were generated.
```
ls -la
```

Copy the certificate to each nodes (to each master & worker nodes)
```
scp ca.pem kubernetes.pem kubernetes-key.pem ubuntu@192.168.x.x:~
scp ca.pem kubernetes.pem kubernetes-key.pem ubuntu@192.168.x.x:~
  ...
scp ca.pem kubernetes.pem kubernetes-key.pem ubuntu@192.168.x.x:~
```


## 4. สร้าง Cluster และ Master node

Set hostname (master node)
```
sudo hostnamectl set-hostname master
```

Set hostname (worker node)
```
sudo hostnamectl set-hostname w1
```

### Installing and configuring Etcd on all 3 Master Nodes

Download and move etcd files and certs to their respective places
```
sudo mkdir /etc/etcd /var/lib/etcd

sudo mv ~/ca.pem ~/kubernetes.pem ~/kubernetes-key.pem /etc/etcd

wget https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz

tar xvzf etcd-v3.4.13-linux-amd64.tar.gz

sudo mv etcd-v3.4.13-linux-amd64/etcd* /usr/local/bin/
```

Create an etcd systemd unit file
```
sudo nano /etc/systemd/system/etcd.service
```

Enter the following config:
```
[Unit]
Description=etcd
Documentation=https://github.com/coreos


[Service]
ExecStart=/usr/local/bin/etcd \
  --name <OWN_MASTER_NODE_IP> \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://<OWN_MASTER_NODE_IP>:2380 \
  --listen-peer-urls https://<OWN_MASTER_NODE_IP>:2380 \
  --listen-client-urls https://<OWN_MASTER_NODE_IP>:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://<OWN_MASTER_NODE_IP>:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster <MASTER_NODE_1_IP>=https://<MASTER_NODE_1_IP>,<MASTER_NODE_2_IP>=https://<MASTER_NODE_2_IP>:2380,<MASTER_NODE_3_IP>=https://<MASTER_NODE_3_IP>:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5



[Install]
WantedBy=multi-user.target
```
Replace the IP address on all fields except the —initial-cluster field to match the machine IP.

Reload the daemon configuration.
```
sudo systemctl daemon-reload
```

Enable etcd to start at boot time.
```
sudo systemctl enable etcd
```

Start etcd.
```
sudo systemctl start etcd
```
> Repeat the process for all 3 master nodes and then move to next step

Verify that the cluster is up and running.
```
ETCDCTL_API=3 etcdctl member list
```

It should give you an output similar to this:
```
73ea126859b3ba4, started, 192.168.1.114, https://192.168.1.114:2380, https://192.168.1.114:2379, false
a28911111213cc6c, started, 192.168.1.115, https://192.168.1.115:2380, https://192.168.1.115:2379, false
feadb5a763a32caa, started, 192.168.1.113, https://192.168.1.113:2380, https://192.168.1.113:2379, false
```

### Initialising the Master Nodes

Initialising the first Master Node

Create the configuration file for kubeadm
```
nano config.yaml
```

Enter the following config:
```
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.19.0
controlPlaneEndpoint: "<LOAD_BALANCER_IP>:6443"
etcd:
  external:
    endpoints:
      - https://<MASTER_NODE_1_IP>:2379
      - https://<MASTER_NODE_2_IP>:2379
      - https://<MASTER_NODE_3_IP>:2379
    caFile: /etc/etcd/ca.pem
    certFile: /etc/etcd/kubernetes.pem
    keyFile: /etc/etcd/kubernetes-key.pem
networking:
  podSubnet: 10.30.0.0/24
apiServer:
  certSANs:
    - "<LOAD_BALANCER_IP>"
  extraArgs:
    apiserver-count: "3"
```
Add any additional domains or IP Addresses that you would want to connect to the cluster under certSANs.

Initialise the machine as a master node
```
sudo kubeadm init --config=config.yaml
```

Copy the certificates to the two other masters
```
sudo scp -r /etc/kubernetes/pki ubuntu@<MASTER_NODE_2_IP>:~
sudo scp -r /etc/kubernetes/pki ubuntu@<MASTER_NODE_3_IP>:~
```

#### Initialising the second Master Node

Remove the apiserver.crt and apiserver.key
```
rm ~/pki/apiserver.*
```

Move the certificates to the `/etc/kubernetes` directory.
```
sudo mv ~/pki /etc/kubernetes/
```

Create the configuration file for kubeadm
```
nano config.yaml
```

Enter the following config:
```
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.19.0
controlPlaneEndpoint: "<LOAD_BALANCER_IP>:6443"
etcd:
  external:
    endpoints:
      - https://<MASTER_NODE_1_IP>:2379
      - https://<MASTER_NODE_2_IP>:2379
      - https://<MASTER_NODE_3_IP>:2379
    caFile: /etc/etcd/ca.pem
    certFile: /etc/etcd/kubernetes.pem
    keyFile: /etc/etcd/kubernetes-key.pem
networking:
  podSubnet: 10.30.0.0/24
apiServer:
  certSANs:
    - "<LOAD_BALANCER_IP>"
  extraArgs:
    apiserver-count: "3"
```

Initialise the machine as a master node.
```
sudo kubeadm init --config=config.yaml
```

> Initialising the third master node (repeat same as the second))


ถ้าเจอ error ประมานนี้
```
[init] Using Kubernetes version: v1.24.1
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR CRI]: container runtime is not running: output: time="2023-01-19T15:05:35Z" level=fatal msg="validate service connection: CRI v1 runtime API is not implemented for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
, error: exit status 1
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
```

ใช้ command
```
sudo rm /etc/containerd/config.toml
sudo systemctl restart containerd
```

ถ้าสำเร็จจะได้ประมานนี้
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.36:6443 --token 2rmgf8.jvwpidbmo1j2zf9e \
	--discovery-token-ca-cert-hash sha256:2559dfd530c5ed63e6f43334dbe5d1261932112f133ab47be1abdb4218a90076
```


Start cluster
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Test to see if you can access the Kubernetes API from the client machine
```
kubectl get nodes
```


Join worker node into master node (worker node only)

ใช้ command ที่ได้หลังจากสร้าง master node
```
kubeadm join 192.168.1.36:6443 --token 2rmgf8.jvwpidbmo1j2zf9e \
	--discovery-token-ca-cert-hash sha256:2559dfd530c5ed63e6f43334dbe5d1261932112f133ab47be1abdb4218a90076
```

ดู nodes อีกรอบที่ master mode
```
kubectl get nodes
```

จะได้
```
NAME           STATUS     ROLES    AGE   VERSION
k8s-master-a   NotReady   master   53m   v1.19.2
k8s-master-b   NotReady   master   20m   v1.19.2
k8s-master-c   NotReady   master   14m   v1.19.2
k8s-node-a     NotReady   <none>   26s   v1.19.2
k8s-node-b     NotReady   <none>   19s   v1.19.2
k8s-node-c     NotReady   <none>   18s   v1.19.2
```

Deploying the overlay network
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Assign role (optional)
```
kubectl label nodes w1 node-role.kubernetes.io/worker=worker
```

Reference
* [Reference](https://tansanrao.com/kubernetes-ha-cluster-with-kubeadm/)

