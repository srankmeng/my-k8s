## Step การติดตั้ง Kubernetes cluster (1 Master node, 2 Worker nodes) ด้วย vagrant
* ติดตั้ง Vagrant
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ  node ทั้ง Master และ Worker node
* สร้าง Master node และ Cluster
* สร้าง Worker node และทำการ join เข้า Cluster

| Node    |      ip       |
|---------|---------------|
| master  | 192.168.10.21 |
| worker1 | 192.168.10.22 |
| worker2 | 192.168.10.23 |

## Vagrant

[Document](https://developer.hashicorp.com/vagrant/tutorials/getting-started/getting-started-install)


### Install Vagrant
macos
```
brew tap hashicorp/tap
brew install hashicorp/tap/hashicorp-vagrant
```
[another os](https://developer.hashicorp.com/vagrant/install#macOS)

### Initialize the project
Create directory then run command line
```
vagrant init ubuntu/focal64
```


### Install a box
Create box
```
vagrant box add ubuntu/focal64
```
Able to install others that you want [Discover Vagrant Boxes](https://app.vagrantup.com/boxes/search)


### Config Vagrantfile
```
Vagrant.configure("2") do |config|

  config.vm.define "worker1" do |worker1|
    worker1.vm.box = "ubuntu/focal64"
    worker1.vm.hostname = "worker1"
    worker1.vm.network "private_network", ip: "192.168.10.22"
  end

  config.vm.define "worker2" do |worker2|
    worker2.vm.box = "ubuntu/focal64"
    worker2.vm.hostname = "worker2"
    worker2.vm.network "private_network", ip: "192.168.10.23"
  end

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/focal64"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.10.21"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

end
```

จากนั้นรัน `vagrant up` เพื่อสร้าง vms เมื่อเรียบร้อยก็ config cluster ต่อได้เลย

### Vagrant cli
Custom Vagrantfile and start
- start `vagrant up`
- suspend `vagrant suspend` / `vagrant suspend {name}`
- shutdown `vagrant halt` / `vagrant halt {name}`
- reload `vagrant reload` / `vagrant reload {name}`
- destroy `vagrant destroy` / `vagrant destroy {name}`
- ssh `vagrant ssh` / `vagrant ssh {name}`
- show status `vagrant status`
- show global status `vagrant global-status`
- show config `vagrant ssh-config` / `vagrant ssh-config {name}`


## Setup cluster

### Setup cluster by manually
[Steps](/docs/1master_2workers/MANUAL.md)

### Setup cluster by script
Update Vagrantfile
```
Vagrant.configure("2") do |config|

  config.vm.define "worker1" do |worker1|
    worker1.vm.box = "ubuntu/focal64"
    worker1.vm.hostname = "worker1"
    worker1.vm.network "private_network", ip: "192.168.10.22"
    worker1.vm.provision "shell", path: "setup/common.sh", privileged: false
  end

  config.vm.define "worker2" do |worker2|
    worker2.vm.box = "ubuntu/focal64"
    worker2.vm.hostname = "worker2"
    worker2.vm.network "private_network", ip: "192.168.10.23"
    worker2.vm.provision "shell", path: "setup/common.sh", privileged: false
  end

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/focal64"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.10.21"
    master.vm.provision "shell", path: "setup/common.sh", privileged: false
    master.vm.provision "shell", path: "setup/master.sh", args: "192.168.10.21", privileged: false
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

end
```
Run `vagrant up` (if you have exit vms, should `vagrant destroy` before)

Waiting then run kubeadm join command in each worker node
```
sudo kubeadm join 192.168.10.21:6443 --token 941nv3.v77jx28mxqkdyqxo \
        --discovery-token-ca-cert-hash sha256:1a5544694a397d9b51c6e6ffafe3cb4fa35f9e9cd3e62dcd0963a70365f554a5
```

ดู nodes ที่ master mode
```
kubectl get nodes
```

จะได้
```
NAME      STATUS     ROLES           AGE     VERSION
master    Ready      control-plane   5m49s   v1.28.2
worker1   NotReady   <none>          27s     v1.28.2
worker2   NotReady   <none>          1s      v1.28.2
```

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