## Step การติดตั้ง Kubernetes cluster (2 Master nodes, 2 external etcd, 2 Worker nodes)
![kubeadm-ha-topology-stacked-etcd](/images/kubeadm-ha-topology-stacked-etcd.svg)
---
![kubeadm-ha-topology-external-etcd](/images/kubeadm-ha-topology-external-etcd.svg)
---

Step ทั้งหมด
1. Setup OS: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)
2. ติดตั้ง Docker: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)
3. ติดตั้ง Kubernetes: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)
4. Setup External etcd
5. สร้าง Master node ตัวแรก
6. สร้าง Worker node ตัวแรก
7. สร้าง Master node ตัวสอง join เข้า cluster
8. สร้าง Worker node ตัวสอง join เข้า cluster
--- 

### 1. Setup OS: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)

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

### 2. ติดตั้ง Docker: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)

Set up Docker's apt repository.
```
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
```

Install the Docker packages.
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 3. ติดตั้ง Kubernetes: ทำทุก nodes (2 Master nodes, 2 external etcd, 2 Worker nodes)

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

<br />

### 4. Setup External etcd
Configure the kubelet **(ทำที่ etcd ทุก nodes)**
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

Install etcdctl for Check the cluster health **(ทำที่ etcd ทุก nodes)**
```
ETCD_RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)

wget https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
tar zxvf etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
sudo mv etcd-${ETCD_RELEASE}-linux-amd64/etcd* /usr/local/bin/
```

:exclamation: :exclamation: Create configuration files for kubeadm 
กำหนดค่าของ HOST0, HOST1, NAME0 และ NAME1 ตาม ip และชื่อของ etcd ของเราไล่ ๆ ไป (ตัวแปรสี่ตัวแรก) **(ทำที่ etcd ทุก nodes)**
```
# Update HOST0, HOST1 and HOST2 with the IPs of your hosts
export HOST0=10.0.0.6 <========= แก้ตรงนี้
export HOST1=10.0.0.7 <========= แก้ตรงนี้

# Update NAME0, NAME1 and NAME2 with the hostnames of your hosts
export NAME0="etcd1" <========= แก้ตรงนี้
export NAME1="etcd2" <========= แก้ตรงนี้

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

Generate the certificate authority **(ทำที่ etcd ตัวแรกเท่านั้น)**
```
kubeadm init phase certs etcd-ca
```

Check ไฟล์ว่ามามั้ย **(ทำที่ etcd ตัวแรกเท่านั้น)**
```
tree /etc/kubernetes/pki/etcd/
```

:computer:  output:
```
/etc/kubernetes/pki/etcd/
├── ca.crt
└── ca.key
```

<br />

### 4.1
Create certificates **(ทำที่ etcd ตัวแรกเท่านั้น)**
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

:exclamation: :exclamation: Copy certificates and kubeadm configs **(ทำที่ etcd ตัวแรกเท่านั้น)**

โดยกำหนด USER เป็นชื่อ username ของอีกเครื่องที่เราจะ copy cert ไปให้ เช่น `USER=root`
```
USER=ubuntu <========= แก้ตรงนี้
HOST=${HOST1}
sudo scp -r /tmp/${HOST}/* ${USER}@${HOST}:
```

:computer: output:
```
kubeadmcfg.yaml                               100%  810   711.5KB/s   00:00    
apiserver-etcd-client.crt                     100% 1155     1.5MB/s   00:00    
apiserver-etcd-client.key                     100% 1675     1.9MB/s   00:00    
healthcheck-client.crt                        100% 1159     1.3MB/s   00:00    
peer.key                                      100% 1675     1.6MB/s   00:00    
ca.crt                                        100% 1094     1.1MB/s   00:00    
peer.crt                                      100% 1192     1.3MB/s   00:00    
server.key                                    100% 1679     1.7MB/s   00:00    
healthcheck-client.key                        100% 1679     1.6MB/s   00:00    
server.crt                                    100% 1192     1.1MB/s   00:00 
```

ไปที่ etcd อีก node แล้วย้าย certificates ไปที่ /etc/kubernetes/ ของเครื่องนั้น **(ทำที่ etcd ตัวที่สองเท่านั้น)**
```
sudo -Es
chown -R root:root pki
mv pki /etc/kubernetes/
```

Check file in directory each node On $HOST0: โดยใช้คำสั่ง **(ทำที่ etcd ตัวแรกเท่านั้น)**
```
tree /tmp/${HOST0}
```
```
tree /etc/kubernetes/pki
```

:computer: output ตามลำดับ:
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

Check file in directory **(ทำที่ etcd ตัวที่สองเท่านั้น)**
```
tree $HOME
```
```
tree /etc/kubernetes/pki
```

:computer: output ตามลำดับ:
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

<br />


### 4.2 Create the static pod manifests

**(ทำที่ etcd ตัวแรกเท่านั้น)**
```
kubeadm init phase etcd local --config=/tmp/${HOST0}/kubeadmcfg.yaml
```
**(ทำที่ etcd ตัวที่สองเท่านั้น)**
```
kubeadm init phase etcd local --config=$HOME/kubeadmcfg.yaml
```

Check the etcd health **(ทำที่ etcd ตัวแรกเท่านั้น)**
```
ETCDCTL_API=3 etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://${HOST0}:2379 endpoint health
```

:computer:  output:
```
https://[HOST0 IP]:2379 is healthy: successfully committed proposal: took = 16.283339ms
```

View member list **(ทำที่ etcd ไหนก็ได้)**

:exclamation: :exclamation: เปลี่ยน `<ETCD_IP>` เป็น ip ของ etcd ไหนก็ได้
```
ETCDCTL_API=3 etcdctl member list \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://<ETCD_IP>:2379 --write-out=table
```
:computer: output:
```
+------------------+---------+--------+------------------------------+------------------------------+------------+
|        ID        | STATUS  |  NAME  |          PEER ADDRS          |         CLIENT ADDRS         | IS LEARNER |
+------------------+---------+--------+------------------------------+------------------------------+------------+
| 2b654c5f343dd2c6 | started | etcd02 | https://128.199.182.170:2380 | https://128.199.182.170:2379 |      false |
| b54829f274fb16e8 | started | etcd01 | https://128.199.181.251:2380 | https://128.199.181.251:2379 |      false |
+------------------+---------+--------+------------------------------+------------------------------+------------+
```

Write **(ทำที่ etcd ไหนก็ได้)**

:exclamation: :exclamation: เปลี่ยน `<ETCD_IP>` เป็น ip ของ etcd ไหนก็ได้
```
etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://<ETCD_IP>:2379 put name meng
```

Read **(ทำที่ etcd ไหนก็ได้)**

:exclamation: :exclamation: เปลี่ยน `<ETCD_IP>` เป็น ip ของ etcd ไหนก็ได้
```
etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://<ETCD_IP>:2379 get name
```

<br />

### 5. สร้าง Master node ตัวแรก

โดยจะเอา cert จาก etcd มาไว้ที่ master node แล้ว initial cluster


:exclamation: :exclamation: Copy certs from any etcd to first master node **(ทำที่ etcd ไหนก็ได้)**
เปลี่ยน `<USERNAME_MASTER_NODE_IP>` เป็น username ของ master node ตัวแรก
เปลี่ยน `<FIRST_MASTER_NODE_IP>` เป็น ip ของ master node ตัวแรก
```
scp -r /etc/kubernetes/pki/etcd/ca.crt <USERNAME_MASTER_NODE_IP>@<FIRST_MASTER_NODE_IP>:
scp -r /etc/kubernetes/pki/apiserver-etcd-client.crt <USERNAME_MASTER_NODE_IP>@<FIRST_MASTER_NODE_IP>:
scp -r /etc/kubernetes/pki/apiserver-etcd-client.key <USERNAME_MASTER_NODE_IP>@<FIRST_MASTER_NODE_IP>:
```

Move certs to /etc/kubernetes/pki/ directory **(ทำที่ master ตัวแรก)**
```
sudo mkdir -p /etc/kubernetes/pki/ /etc/kubernetes/pki/etcd
sudo mv ca.crt /etc/kubernetes/pki/etcd
sudo mv apiserver-etcd-client.crt /etc/kubernetes/pki/
sudo mv apiserver-etcd-client.key /etc/kubernetes/pki/
```

Create kubeadm-config file **(ทำที่ master ตัวแรก)**
```
sudo nano kubeadm-config.yaml
```

:exclamation: :exclamation: เปลี่ยน endpoint เป็นของเรา 3 ที่ด้านล่าง
```
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "192.168.10.20:6443" <=========== เปลี่ยนเป็น master1 ip
etcd:
  external:
    endpoints:
      - https://192.168.10.24:2379  <=========== เปลี่ยนเป็น etcd01 ip
      - https://192.168.10.25:2379 <=========== เปลี่ยนเป็น etcd02 ip
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  podSubnet: "10.244.0.0/16"
```
<!-- 
>or maybe for some network
>```
>apiVersion: kubeadm.k8s.io/v1beta3
>kind: ClusterConfiguration
>kubernetesVersion: stable
>controlPlaneEndpoint: "192.168.10.20:6443"
>etcd:
>  external:
>    endpoints:
>      - https://192.168.10.24:2379
>      - https://192.168.10.25:2379
>    caFile: /etc/kubernetes/pki/etcd/ca.crt
>    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
>    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
>networking:
>  podSubnet: "10.244.0.0/16"
>---
>apiVersion: kubeadm.k8s.io/v1beta3
>kind: InitConfiguration
>localAPIEndpoint:
>  advertiseAddress: 192.168.10.20
>  bindPort: 6443
>``` -->

Initialize Kubernetes on Master Node **(ทำที่ master ตัวแรก)**
```
sudo kubeadm init --config kubeadm-config.yaml --upload-certs
```

:computer: output:
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

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 192.168.10.20:6443 --token 3gn14b.kkf17ebqbs3dnfyh \
        --discovery-token-ca-cert-hash sha256:393523381b84172d26207d48c768ef53689b47878041e42854ac76dac7b527ce \
        --control-plane --certificate-key 7b6b357210d9ff61eea2cdeded5ee85a710b1881631ee1b5d2c502cdaa645028

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.10.20:6443 --token 3gn14b.kkf17ebqbs3dnfyh \
        --discovery-token-ca-cert-hash sha256:393523381b84172d26207d48c768ef53689b47878041e42854ac76dac7b527ce 
```

> [!IMPORTANT]  
> จะเห็นว่าจะได้ command join ของทั้ง master และ worker ให้เก็บไว้ทั้งสองคำสั่ง
> ```
>   kubeadm join 192.168.10.20:6443 --token 3gn14b.kkf17ebqbs3dnfyh \
>         --discovery-token-ca-cert-hash sha256:393523381b84172d26207d48c768ef53689b47878041e42854ac76dac7b527ce \
>         --control-plane --certificate-key 7b6b357210d9ff61eea2cdeded5ee85a710b1881631ee1b5d2c502cdaa645028
> ```
> และ
> ```
> kubeadm join 192.168.10.20:6443 --token 3gn14b.kkf17ebqbs3dnfyh \
>         --discovery-token-ca-cert-hash sha256:393523381b84172d26207d48c768ef53689b47878041e42854ac76dac7b527ce 
> ```


Start cluster **(ทำที่ master ตัวแรก)**
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Deploy Pod Network to Cluster **(ทำที่ master ตัวแรก)**
```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
```

Verify that everything is running
```
kubectl get nodes
kubectl get pods -A
```

<br />

### 6. สร้าง Worker node ตัวแรก
Join worker node into cluster **(ทำที่ worker ตัวแรก)**

:exclamation: :exclamation: ใช้ command ที่ได้หลังจากสร้าง master node 
```
kubeadm join 192.168.10.20:6443 --token udw6s6.ag5stldgmyxrxqlo \
  --discovery-token-ca-cert-hash sha256:07cb0fea26d34e23df4af8d9d654d06775ab1fbb3a6c3bdd04816b5ccc877c98
```

ดูผลที่ master node
```
kubectl get nodes
```

<br />


### 7. สร้าง Master node ตัวสอง join เข้า cluster
Join master node into cluster **(ทำที่ master ตัวสอง)**

:exclamation: :exclamation: ใช้ command ที่ได้หลังจากสร้าง master node แรก ที่เป็นของ master node
```
kubeadm join 128.199.113.251:6443 --token dlcqrx.06jqcrw78s54f6s4 \
	--discovery-token-ca-cert-hash sha256:a316f0bcc7ae6a8e992de7246a1fe3d3539e4999c6f2dec9063df951bbedf0de \
	--control-plane --certificate-key c16c6687a174ca6ccb2fe5c5d4f6f6e9b62cb43e1a33fd9da005bf35e985a4ed
```

จากนั้น **(ทำที่ master ตัวสอง)**
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

ดูผลที่ master node
```
kubectl get nodes
```

<br />


### 8. สร้าง Worker node ตัวสอง join เข้า cluster
Join worker node into cluster **(ทำที่ worker ตัวสอง)**

:exclamation: :exclamation: ใช้ command ที่ได้หลังจากสร้าง master node 
```
kubeadm join 192.168.10.20:6443 --token udw6s6.ag5stldgmyxrxqlo \
  --discovery-token-ca-cert-hash sha256:07cb0fea26d34e23df4af8d9d654d06775ab1fbb3a6c3bdd04816b5ccc877c98
```

ดูผลที่ master node
```
kubectl get nodes
```


จะได้
```
NAME     STATUS   ROLES           AGE     VERSION
master1   Ready    control-plane   4h37m   v1.28.2
master2   Ready    control-plane   4h25m   v1.28.2
worker1   Ready    <none>          4h19m   v1.28.2
worker2   Ready    <none>          4h17m   v1.28.2
```
เป็นอันเรียบร้อยสำหรับการสร้าง cluster


## ลองรัน Nginx
สร้างไฟล์ nginx.yaml
```
nano nginx.yaml
```

ตามนี้
```
apiVersion: v1
kind: Service
metadata:
  name: nginx-project
spec:
  type: NodePort
  selector:
    app: nginx-project
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30181
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-project
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-project
  template:
    metadata:
      labels:
        app: nginx-project
    spec:
      containers:
        - name: nginx
          image: nginx:1.17.3
          ports:
            - containerPort: 80
```

apply
```
kubectl apply -f nginx.yaml
```

delete
```
kubectl delete -f nginx.yaml
```

ดู pods ว่าขึ้นมั้ย ด้วย
```
kubectl get pods
```

จะได้
```
NAME                             READY   STATUS    RESTARTS   AGE
nginx-project-78b94b9cc8-7brtm   1/1     Running   0          7m38s
nginx-project-78b94b9cc8-brnmp   1/1     Running   0          7m38s
```

เข้าไปดูว่าขึ้น nginx มั้ย
```
kubectl get svc -o wide
```

ดู port ที่รันอยู่ จากตัวอย่างอยู่ที่ port 30181
```
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        11m   <none>
nginx-project   NodePort    10.107.100.206   <none>        80:30181/TCP   7s    app=nginx-project
```

เอา ip address ของ worker node มายิงดู
```
curl 192.168.10.22:30181 or 
curl 192.168.10.23:30181
```