## Step การติดตั้ง Kubernetes cluster (2 Master nodes, 2 external etcd, 2 Worker nodes)
* Setup external etcd cluster
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ  node ทั้ง Master และ Worker node
* สร้าง Master node และ Cluster + copy certs from etcd + join master node
* สร้าง Worker node และทำการ join เข้า Cluster

| Node    |      ip       |
|---------|---------------|
| master1 | 192.168.10.20 |
| master2 | 192.168.10.21 |
| worker1 | 192.168.10.22 |
| worker2 | 192.168.10.23 |
| etcd1   | 192.168.10.24 |
| etcd2   | 192.168.10.25 |

## 1. Setup external etcd cluster

- [manual](/docs/external_etcd/MANUAL.md)
- [vagrant](/docs/external_etcd/VAGRANT.md)

## 2. ติดตั้ง Docker บน Ubuntu (all of master & worker nodes)
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

## 3. ติดตั้ง Kubernetes บน Ubuntu (all of master & worker nodes)


ปิดการใช้งาน swap 
```
sudo swapoff -a
sudo sed -i 's/^.*swap/#&/' /etc/fstab
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

## 4. สร้าง Cluster และ Master node
Set hostname (master node)
```
sudo hostnamectl set-hostname master
```

Set hostname (worker node)
```
sudo hostnamectl set-hostname w1
```

Copy certs from any etcd to first master node (run on any etcd)
```
$ scp -r /etc/kubernetes/pki/etcd/ca.crt username@192.168.10.20:
$ scp -r /etc/kubernetes/pki/apiserver-etcd-client.crt username@192.168.10.20:
$ scp -r /etc/kubernetes/pki/apiserver-etcd-client.key username@192.168.10.20:
```

Move certs to /etc/kubernetes/pki/ directory (first master node)
```
$ sudo mkdir -p /etc/kubernetes/pki/ /etc/kubernetes/pki/etcd
$ sudo mv ca.crt /etc/kubernetes/pki/etcd
$ sudo mv apiserver-etcd-client.crt /etc/kubernetes/pki/
$ sudo mv apiserver-etcd-client.key /etc/kubernetes/pki/
```

Create kubeadm-config file (first master node)
```
sudo nano kubeadm-config.yaml
```

```
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "192.168.10.20:6443"
etcd:
  external:
    endpoints:
      - https://192.168.10.24:2379
      - https://192.168.10.25:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
    podSubnet: "10.244.0.0/16"
```

Initialize Kubernetes on Master Node (first master node)
```
sudo kubeadm init --config kubeadm-config.yaml --upload-certs
```

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
$ sudo rm /etc/containerd/config.toml
$ sudo systemctl restart containerd
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


Start cluster
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Deploy Pod Network to Cluster
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Verify that everything is running
```
kubectl get nodes
kubectl get pods -A
```

Join master node into master node (master node only)
ใช้ command ที่ได้หลังจากสร้าง master node
```
kubeadm join 192.168.10.20:6443 --token udw6s6.ag5stldgmyxrxqlo \
  --discovery-token-ca-cert-hash sha256:07cb0fea26d34e23df4af8d9d654d06775ab1fbb3a6c3bdd04816b5ccc877c98 \
  --control-plane --certificate-key 7cac221ab2643bbd61b68a90843bc5222eb07941ef832f0123274e323a626716
```

Join worker node into master node (worker node only)

ใช้ command ที่ได้หลังจากสร้าง master node
```
kubeadm join 192.168.10.20:6443 --token udw6s6.ag5stldgmyxrxqlo \
  --discovery-token-ca-cert-hash sha256:07cb0fea26d34e23df4af8d9d654d06775ab1fbb3a6c3bdd04816b5ccc877c98
```

ดู nodes อีกรอบที่ master mode
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
touch nginx.yaml
```

แก้ไขไฟล์ 
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