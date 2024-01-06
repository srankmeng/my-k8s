## Step การติดตั้ง Kubernetes cluster (1 Master node, 2 Worker nodes)
* Setup OS
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ  node ทั้ง Master และ Worker node
* สร้าง Master node และ Cluster
* สร้าง Worker node และทำการ join เข้า Cluster

| Node    |      ip       |
|---------|---------------|
| master  | 192.168.10.21 |
| worker1 | 192.168.10.22 |
| worker2 | 192.168.10.23 |

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

update kubelet with ip (replace node ip in `<NODE_IP>`)
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

## 4. สร้าง Cluster และ Master node
Set hostname (master node)
```
sudo hostnamectl set-hostname master
```

Set hostname (worker node)
```
sudo hostnamectl set-hostname w1
```

Initialize Kubernetes on Master Node (master node only)
```
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

OR
```
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address={PUBLIC_IP}
```

>ถ้าเจอ error ประมานนี้
>```
>[init] Using Kubernetes version: v1.24.1
>[preflight] Running pre-flight checks
>error execution phase preflight: [preflight] Some fatal errors occurred:
>        [ERROR CRI]: container runtime is not running: output: time="2023-01-19T15:05:35Z" level=fatal msg="validate service connection: CRI v1 runtime API is not implemented for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
>, error: exit status 1
>[preflight] If you know what you are doing, you can make a check non-fatal >with `--ignore-preflight-errors=...`
>```
>
>ใช้ command
>```
>sudo rm /etc/containerd/config.toml
>sudo systemctl restart containerd
>```

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

Deploy Pod Network to Cluster
```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
```

Verify that everything is running
```
kubectl get nodes
kubectl get pods -A
```

Join worker node into master node (worker node only)

ใช้ command ที่ได้หลังจากสร้าง master node
```
kubeadm join 192.168.1.36:6443 --token 2rmgf8.jvwpidbmo1j2zf9e \
	--discovery-token-ca-cert-hash sha256:2559dfd530c5ed63e6f43334dbe5d1261932112f133ab47be1abdb4218a90076
```

> ถ้าไม่ได้เก็บไว้ ให้ generate token
>```
>kubeadm token create --print-join-command
>```

ดู nodes อีกรอบที่ master mode
```
kubectl get nodes
```

จะได้
```
NAME     STATUS   ROLES           AGE     VERSION
master   Ready    control-plane   4m48s   v1.28.2
w1       Ready    <none>          7s      v1.28.2
w2       Ready    <none>          3s      v1.28.2
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