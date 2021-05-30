#!/usr/bin/env bash

initial_time=`date +%s`
vm_num=$1

echo ""
echo "*********************************************************"
echo "** EXTRA ** Initial install of Zscaler cert to allow communication to internet"
mv /tmp/zscaler-cert.crt /usr/local/share/ca-certificates/zscaler-cert.crt
update-ca-certificates
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "1) Disable swap"
echo "*********************************************************"
swapoff -a
# Keep swap off after restart
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
cat /etc/fstab
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "2) Install prerequisits for containerd"
echo "*********************************************************"
modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "3) Apply sysctl params without reboot"
echo "*********************************************************"
sysctl --system
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "4) Install containerd"
echo "*********************************************************"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y containerd
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "5) Create a containerd configuration file"
echo "*********************************************************"
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "6) Setting the cgroup driver for containerd to systemd which is required for the kubelet by modifying /etc/containerd/config.toml"
echo "*********************************************************"
sed -i '85 s/privileged_without_host_devices = false/privileged_without_host_devices = false\
          \[plugins.'\"'io\.containerd\.grpc\.v1\.cri'\"'\.containerd\.runtimes\.runc\.options\]\
            SystemdCgroup = true/' /etc/containerd/config.toml

echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "7) Restart containerd"
echo "*********************************************************"
systemctl restart containerd
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "8) Install Kubernetes packages -kubadm, kubelet, kubectl"
echo "*********************************************************"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "9) Add Kubernetes apt repository"
echo "*********************************************************"
bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "10) Update the package list and use apt-cache polocy to inspect version available in the repository"
echo "*********************************************************"
apt-get update
apt-cache policy kubelet | head -n 20
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "11) Install the require packages"
echo "*********************************************************"
VERSION=1.20.1-00
apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
apt-mark hold kubelet kubeadm kubectl containerd
#To install the latest, omit the version parameters
#sudo apt-get install kubelet kubeadm kubectl
#sudo apt-mark hold kubelet kubeadm kubectl containerd
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "** EXTRA ** SETTING UP SERVER IP TO AVOID USING ETH0 (NAT) ON VIRTUALBOX"
echo "*********************************************************"
sed -i "s/Environment=\"KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml\"/Environment=\"KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=172\.16\.94\.1${vm_num}\"/" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "12) Check kubelet and containerd services"
echo "*********************************************************"
systemctl status kubelet.service
systemctl status containerd.service
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "13) Ensure both are set to start when the system starts up"
echo "*********************************************************"
systemctl enable kubelet.service
systemctl enable containerd.service
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "14) ---------- Nodes can now be joined to the cluster ----------"
echo "*********************************************************"
echo ""
#JOIN=`(ssh vagrant:vagrant@172.16.94.10 'cat /home/vagrant/join.txt')`
echo "*********************************************************"
echo "*********************************************************"
echo ""

echo "*********************************************************"
end_time=`date +%s`
runtime=$(((end_time-initial_time)/60))
echo "FINISHED NODE.SH with $runtime minutes"
echo "*********************************************************"