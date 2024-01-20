## Step การติดตั้ง Kubernetes cluster (2 external etcd nodes)
* [Reference 1](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/)
* [Reference 2](https://weng-albert.medium.com/building-high-availability-external-etcd-cluster-with-static-pods-step-by-step-en-84e9f3328b09)

| Node    |      ip       |
|---------|---------------|
| etcd1   | 192.168.10.24 |
| etcd2   | 192.168.10.25 |

## 1. Setup OS

ปิดการใช้งาน swap 
```
sudo swapoff -a
sudo sed -i 's/^.*swap/#&/' /etc/fstab
```

install tree lib 
```
sudo apt-get install tree
```

Add Kernel Parameters
```
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
```

Configure kernel parameters
```
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

## 2. ติดตั้ง Docker บน Ubuntu
* [Reference](https://docs.docker.com/engine/install/ubuntu/)

รันเพื่อทดสอบว่าใช้ได้ 

```
sudo docker version
```

:computer: output
```
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

## 3. ติดตั้ง Kubernetes บน Ubuntu

Enter the following to add a signing key in you on Ubuntu
```
sudo apt update

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

Add Software Repositories: Kubernetes is not included in the default repositories. To add them, enter the following
```
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
```

Configure containerd
```
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
```

Install Kubeadm
```
sudo apt update   
sudo apt install -y kubeadm
```

:exclamation: :exclamation: update kubelet with ip (replace node ip in `<NODE_IP>`)
```
echo "KUBELET_EXTRA_ARGS=--node-ip=<NODE_IP>" | sudo tee /etc/default/kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart containerd
```

Check
```
kubeadm --help
kubectl --help
kubelet --help
```

## 4. สร้าง Cluster และ etcd node
Configure the kubelet (all etcd nodes)
```
cat << EOF > /etc/systemd/system/kubelet.service.d/kubelet.conf
# Replace "systemd" with the cgroup driver of your container runtime. The default value in the kubelet is "cgroupfs".
# Replace the value of "containerRuntimeEndpoint" for a different container runtime if needed.
#
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
cgroupDriver: systemd
address: 127.0.0.1
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
staticPodPath: /etc/kubernetes/manifests
EOF

cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/etc/systemd/system/kubelet.service.d/kubelet.conf
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet
```

<br />

:exclamation: :exclamation: Create configuration files for kubeadm (all etcd nodes)

กำหนดค่าของ HOST0, HOST1, NAME0 และ NAME1 ตาม ip และชื่อของ etcd ของเราไล่ ๆ ไป (ตัวแปรสี่ตัวแรก)

```
# Update HOST0, HOST1 and HOST2 with the IPs of your hosts
export HOST0=10.0.0.6
export HOST1=10.0.0.7

# Update NAME0, NAME1 and NAME2 with the hostnames of your hosts
export NAME0="etcd1"
export NAME1="etcd2"

# Create temp directories to store files that will end up on other hosts
mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/

HOSTS=(${HOST0} ${HOST1})
NAMES=(${NAME0} ${NAME1})

for i in "${!HOSTS[@]}"; do
HOST=${HOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
---
apiVersion: "kubeadm.k8s.io/v1beta3"
kind: InitConfiguration
nodeRegistration:
    name: ${NAME}
localAPIEndpoint:
    advertiseAddress: ${HOST}
---
apiVersion: "kubeadm.k8s.io/v1beta3"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: ${NAMES[0]}=https://${HOSTS[0]}:2380,${NAMES[1]}=https://${HOSTS[1]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
done
```

Generate the certificate authority(on etcd 1 only)
```
kubeadm init phase certs etcd-ca
```
>:computer: This creates two files:
>```
>/etc/kubernetes/pki/etcd/
>├── ca.crt
>└── ca.key
>```

<br />

#### 4.1
Create certificates for each member. (on etcd 1 only)
```
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
```

:exclamation: :exclamation: Copy certificates and kubeadm configs. (on etcd 1 only)

โดยกำหนด USER เป็นชื่อ username ของอีกเครื่องที่เราจะ copy cert ไปให้ เช่น `USER=ubuntu`
```
USER=ubuntu
HOST=${HOST1}
sudo scp -r /tmp/${HOST}/* ${USER}@${HOST}:
```

ไปที่ etcd อีก node แล้วย้าย certificates ไปที่ /etc/kubernetes/ ของเครื่องนั้น
```
sudo -Es
chown -R root:root pki
mv pki /etc/kubernetes/
```

Check file in directory each node
On `$HOST0`: โดยใช้คำสั่ง
```
tree /tmp/${HOST0}
```
```
tree /etc/kubernetes/pki
```

:computer: output
```
/tmp/${HOST0}
└── kubeadmcfg.yaml
---
/etc/kubernetes/pki
├── apiserver-etcd-client.crt
├── apiserver-etcd-client.key
└── etcd
    ├── ca.crt
    ├── ca.key
    ├── healthcheck-client.crt
    ├── healthcheck-client.key
    ├── peer.crt
    ├── peer.key
    ├── server.crt
    └── server.key
```

On `$HOST1`:
```
tree $HOME
```
```
tree /etc/kubernetes/pki
```

:computer: output
```
$HOME
└── kubeadmcfg.yaml
---
/etc/kubernetes/pki
├── apiserver-etcd-client.crt
├── apiserver-etcd-client.key
└── etcd
    ├── ca.crt
    ├── healthcheck-client.crt
    ├── healthcheck-client.key
    ├── peer.crt
    ├── peer.key
    ├── server.crt
    └── server.key
```

#### 4.2
Create the static pod manifests (depend on each nodes)

On `$HOST0`:
```
kubeadm init phase etcd local --config=/tmp/${HOST0}/kubeadmcfg.yaml
```

On `$HOST1`:
```
kubeadm init phase etcd local --config=$HOME/kubeadmcfg.yaml
```

Install etcdctl for Check the cluster health (all etcd nodes)
```
ETCD_RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)

wget https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
tar zxvf etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
sudo mv etcd-${ETCD_RELEASE}-linux-amd64/etcd* /usr/local/bin/
```

Check the cluster health.
```
ETCDCTL_API=3 etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://${HOST0}:2379 endpoint health
```

:computer: output
```
https://[HOST0 IP]:2379 is healthy: successfully committed proposal: took = 16.283339ms
https://[HOST1 IP]:2379 is healthy: successfully committed proposal: took = 19.44402ms
```

View member list.
```
ETCDCTL_API=3 etcdctl member list \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.25:2379 --write-out=table
```

Write
```
etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.25:2379 put name meng
```

Read
```
etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.25:2379 get name
```