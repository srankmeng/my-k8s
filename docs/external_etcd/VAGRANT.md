## Step การติดตั้ง Kubernetes cluster (2 external etcd nodes) ด้วย vagrant
* ติดตั้ง Vagrant และ vagrant-scp
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ node
* สร้าง etcd node และ Cluster

| Node    |      ip       |
|---------|---------------|
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
  config.vm.provision "shell", path: "setup/gen_ssh.sh", privileged: false

  config.vm.define "etcd2" do |etcd2|
    etcd2.vm.box = "ubuntu/focal64"
    etcd2.vm.hostname = "etcd2"
    etcd2.vm.network "private_network", ip: "192.168.10.25"
  end

  config.vm.define "etcd1" do |etcd1|
    etcd1.vm.box = "ubuntu/focal64"
    etcd1.vm.hostname = "etcd1"
    etcd1.vm.network "private_network", ip: "192.168.10.24"
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

### Install Vagrant scp
```
vagrant plugin install vagrant-scp
```

## Setup etcd cluster

### Setup cluster by manually
[Steps](/docs/external_etcd/MANUAL.md)

### Setup cluster by script
Update Vagrantfile
```
Vagrant.configure("2") do |config|
  config.vm.provision "shell", path: "setup/gen_ssh.sh", privileged: false

  config.vm.define "etcd2" do |etcd2|
    etcd2.vm.box = "ubuntu/focal64"
    etcd2.vm.hostname = "etcd2"
    etcd2.vm.network "private_network", ip: "192.168.10.25"
    etcd2.vm.provision "shell", path: "setup/common.sh", privileged: false
    etcd2.vm.provision "shell", path: "setup/etcd_common.sh", args: "192.168.10.24 192.168.10.25 etcd1 etcd2", privileged: true
  end

  config.vm.define "etcd1" do |etcd1|
    etcd1.vm.box = "ubuntu/focal64"
    etcd1.vm.hostname = "etcd1"
    etcd1.vm.network "private_network", ip: "192.168.10.24"
    etcd1.vm.provision "shell", path: "setup/common.sh", privileged: false
    etcd1.vm.provision "shell", path: "setup/etcd_common.sh", args: "192.168.10.24 192.168.10.25 etcd1 etcd2", privileged: true
    etcd1.vm.provision "shell", path: "setup/etcd_certs.sh", args: "192.168.10.24 192.168.10.25", privileged: false
  end

end
```
Run `vagrant up` (if you have exit vms, should `vagrant destroy` before)


When finish go to etcd2 and move pki 
```
$ vagrant ssh etcd2

$ sudo mv pki /etc/kubernetes/
```

Initial etcd
```
sudo kubeadm init phase etcd local --config=$HOME/kubeadmcfg.yaml
```

Check the cluster health.
```
$ ETCDCTL_API=3 etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.24:2379 endpoint health

...
https://[HOST0 IP]:2379 is healthy: successfully committed proposal: took = 16.283339ms
https://[HOST1 IP]:2379 is healthy: successfully committed proposal: took = 19.44402ms
```

View member list.
```
$ ETCDCTL_API=3 etcdctl member list \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.24:2379 --write-out=table

...
17cfa8f82af3676e, started, etcd1, https://192.168.10.24:2380, https://192.168.10.24:2379, false
9da3e67aca53ba11, started, etcd2, https://192.168.10.25:2380, https://192.168.10.25:2379, false
```

Write
```
$ etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.25:2379 put name meng
```

Read
```
$ etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.10.25:2379 get name
```