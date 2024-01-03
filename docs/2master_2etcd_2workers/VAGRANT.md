## Step การติดตั้ง Kubernetes cluster (2 Master nodes, 2 external etcd, 2 Worker nodes)
* ติดตั้ง Vagrant
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

  config.vm.define "master1" do |master1|
    master1.vm.box = "ubuntu/focal64"
    master1.vm.hostname = "master1"
    master1.vm.network "private_network", ip: "192.168.10.20"
    master1.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

  config.vm.define "master2" do |master2|
    master2.vm.box = "ubuntu/focal64"
    master2.vm.hostname = "master2"
    master2.vm.network "private_network", ip: "192.168.10.21"
    master2.vm.provider "virtualbox" do |vb|
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

## Setup external etcd cluster

- [manual](/docs/external_etcd/MANUAL.md)
- [vagrant](/docs/external_etcd/VAGRANT.md)

## Setup cluster

After already setup etcd cluster, then setup master & worker nodes

### Setup cluster by script
Initial nodes (each node include docker & kubeadm & kubelet & kubectl)

Add worker1,worker2,master1,master2, on Vagrantfile
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

  config.vm.define "master1" do |master1|
    master1.vm.box = "ubuntu/focal64"
    master1.vm.hostname = "master1"
    master1.vm.network "private_network", ip: "192.168.10.20"
    master1.vm.provision "shell", path: "setup/common.sh", privileged: false
    master1.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

  config.vm.define "master2" do |master2|
    master2.vm.box = "ubuntu/focal64"
    master2.vm.hostname = "master2"
    master2.vm.network "private_network", ip: "192.168.10.21"
    master2.vm.provision "shell", path: "setup/common.sh", privileged: false
    master2.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

end
```
Run `vagrant up worker1 worker2 master1 master2`

### Setup cluster by manually

After etcd cluster and each node include docker & kubeadm & kubelet & kubectl

[Steps](/docs/2master_2etcd_2workers/MANUAL.md)

