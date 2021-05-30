# -*- mode: ruby -*-
# vi: set ft=ruby :


BOX_IMAGE = "bento/ubuntu-18.04"
NODE_COUNT = 3

Vagrant.configure(2) do |config|
  ########################### Creating Control Plane Node (master) for the K8 cluster ###########################
  config.vm.define "k8_control_plane_node1", primary: true do |k8_control_plane_node1|
    k8_control_plane_node1.vm.box = BOX_IMAGE
    k8_control_plane_node1.vm.box_download_insecure = true
    k8_control_plane_node1.vm.hostname = "c1-cp1"
    k8_control_plane_node1.vm.network "forwarded_port", guest: 6443, host: 6443
    k8_control_plane_node1.vm.network "private_network", ip: "172.16.94.10",
      virtualbox__intnet: true
       
    k8_control_plane_node1.vm.provider "virtualbox" do |vb|
      # Customize the name of the Virtual box on the VM:
      vb.name = "K8_Control_Plane_Node_VM"
      # Customize the amount of memory on the VM:
      vb.memory = "2048"
      vb.cpus = "2"
    end
    
    ########################### OPTIONAL - Copy Zscaler cert to allow communication to internet ###############################
    k8_control_plane_node1.vm.provision "file", source: "./zscaler-cert.crt", destination: "/tmp/zscaler-cert.crt"

    ########################### Install and configure Kubernetes Control Plane (master) in the cluster #############
    k8_control_plane_node1.vm.provision "shell", path: "src/plane-node.sh"

  end


  ########################### Creating 3 Nodes for the K8 cluster ###########################
  (1..NODE_COUNT).each do |i|
    config.vm.define "k8_node#{i}" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
      subconfig.vm.box_download_insecure = true
      subconfig.vm.hostname = "c1-node#{i}"
      subconfig.vm.network "forwarded_port", guest: "801#{i}", host: "801#{i}"
      subconfig.vm.network "private_network", ip: "172.16.94.1#{i}",
        virtualbox__intnet: true

      subconfig.vm.provider "virtualbox" do |vb|  
        # Customize the name of the Virtual box on the VM:  
        vb.name = "K8_Node#{i}_VM"
        # Customize the amount of memory on the VM:
        vb.memory = "2048"
        vb.cpus = "2"
      end
      
      ########################### OPTIONAL - Copy Zscaler cert to allow communication to internet ################
      subconfig.vm.provision "file", source: "./zscaler-cert.crt", destination: "/tmp/zscaler-cert.crt"

      ########################### Configuring in /etc/hosts the IP I have chosen to have each node ###############
      subconfig.vm.provision "shell", inline: "sed -i '1 i\\172.16.94.1#{i} k8_node#{i}' /etc/hosts"

      ########################### Install and configure Kubernetes Nodes in the cluster ##########################
      subconfig.vm.provision "shell", path: "src/nodes.sh", args: "#{i}"

      ########################### Configuring IP routing tables to look at control plane node which by default uses eth01 (NAT) ip 10.96.0.1 ###############
      subconfig.vm.provision "shell", inline: "route add 10.96.0.1 gw 172.16.94.1#{i}" 

    end

  end

end