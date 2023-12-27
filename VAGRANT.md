## Step การติดตั้ง Kubernetes cluster (1 Master node, 2 Worker nodes) ด้วย vagrant
* ติดตั้ง Vagrant
* ติดตั้ง Docker และ Kubernetes ในทุก ๆ  node ทั้ง Master และ Worker node
* สร้าง Master node และ Cluster
* สร้าง Worker node และทำการ join เข้า Cluster

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
vagrant init ubuntu/bionic64
```


### Install a box
Create box
```
vagrant box add hashicorp/bionic64
```
Able to install others that you want [Discover Vagrant Boxes](https://app.vagrantup.com/boxes/search)


### Config Vagrantfile
```
Vagrant.configure("2") do |config|

  config.vm.define "worker1" do |worker1|
    worker1.vm.box = "ubuntu/bionic64"
    worker1.vm.hostname = "worker1"
    worker1.vm.network "private_network", ip: "192.168.10.22"
  end

  config.vm.define "worker2" do |worker2|
    worker2.vm.box = "ubuntu/bionic64"
    worker2.vm.hostname = "worker2"
    worker2.vm.network "private_network", ip: "192.168.10.23"
  end

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/bionic64"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.10.21"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
  end

end
```

จากนั้นรัน `vagrant up` เพื่อสร้าง vms เมื่อเรียบร้อยก็ manual config cluster ต่อได้เลย

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


### Setup cluster by script
Update Vagrantfile
```
Vagrant.configure("2") do |config|

  config.vm.define "worker1" do |worker1|
    worker1.vm.box = "ubuntu/bionic64"
    worker1.vm.hostname = "worker1"
    worker1.vm.network "private_network", ip: "192.168.10.22"
    worker1.vm.provision "shell", path: "setup/common.sh", privileged: false
  end

  config.vm.define "worker2" do |worker2|
    worker2.vm.box = "ubuntu/bionic64"
    worker2.vm.hostname = "worker2"
    worker2.vm.network "private_network", ip: "192.168.10.23"
    worker2.vm.provision "shell", path: "setup/common.sh", privileged: false
  end

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/bionic64"
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