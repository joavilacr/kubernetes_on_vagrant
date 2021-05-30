#!/usr/bin/env bash

initial_time=`date +%s`
echo ""
echo "*********************************************************"
echo "** EXTRA ** Initial install of Zscaler cert to allow communication to internet"
echo "*********************************************************"
mv /tmp/zscaler-cert.crt /usr/local/share/ca-certificates/zscaler-cert.crt
update-ca-certificates
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "1) Disable swap."
echo "*********************************************************"
swapoff -a
# Keep swap off after restart
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
cat /etc/fstab
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "2) Install prerequisits for containerd."
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
echo "3) Apply sysctl params without reboot."
echo "*********************************************************"
sysctl --system
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "4) Install containerd."
echo "*********************************************************"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y containerd
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "5) Create a containerd configuration file."
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
echo "7) Restart containerd."
echo "*********************************************************"
systemctl restart containerd
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "8) Install Kubernetes packages -kubadm, kubelet, kubectl."
echo "*********************************************************"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "9) Add Kubernetes apt repository."
echo "*********************************************************"
bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "10) Update the package list and use apt-cache polocy to inspect version available in the repository."
echo "*********************************************************"
apt-get update
apt-cache policy kubelet | head -n 20
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "11) Install the require packages."
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
echo "** EXTRA ** SETTING UP SERVER IP"
echo "*********************************************************"
sed -i 's/Environment='\"'KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml'\"'/Environment='\"'KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=172\.16\.94\.10'\"'/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

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
echo "14) Setting up server to add nodes into the cluster through calico.yaml"
echo "*********************************************************"
wget https://docs.projectcalico.org/manifests/calico.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "15) Check IPV of the calico.yaml to not overlap any IP being used by the cluster"
echo "*********************************************************"
#cat calico.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "16) Define setting that the cluster kubeadm will create for us"
kubeadm config print init-defaults | tee ClusterConfiguration.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "17) Update ClusterConfiguration.yaml to use Containerd (for this test)."
echo "*********************************************************"
echo "    Check the IP being used and update if needed:"
sed -i 's/advertiseAddress: 1.2.3.4/advertiseAddress: 172.16.94.10/' ClusterConfiguration.yaml
echo ""

echo "    Change from default (Docker) to Containerd setting:"
sed -i 's/criSocket: \/var\/run\/dockershim\.sock/criSocket: \/run\/containerd\/containerd\.sock/' ClusterConfiguration.yaml
echo ""

echo "    Include api settings:"
cat <<EOF | cat >> ClusterConfiguration.yaml
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
echo ""

echo "    Update version of kubernetes installed:"
sed -i 's/kubernetesVersion: v1.20.0/kubernetesVersion: v1.20.1/' ClusterConfiguration.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "18) Bootstrap the cluster together."
echo "*********************************************************"
kubeadm init --config=ClusterConfiguration.yaml --cri-socket /run/containerd/containerd.sock
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "19) Configure our account on the Control Plane Node to have admin access to the API server from a non-privileged account."
echo "*********************************************************"
HOME="/home/vagrant"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#chown $(id -u):$(id -g) $HOME/.kube/config
chown 1000:1000 $HOME/.kube/config
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "*********** Creating a Pod Network ***********"
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "20) Deploying CALICO yaml file as a pod for our network."
echo "*********************************************************"
echo "APPLYING kubectl calico.yaml."
kubectl apply -f calico.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "21) Look for the all the system pods and calico pods to change to Running."
echo "*********************************************************"
#The DNS pod won't start (pending) until the Pod network is deployed and Running.
echo "GETTING POTS FROM ALL NAMESPACES WITH KUBECTL"
kubectl get pods --all-namespaces
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "22) Get a list of our current nodes, just the Control Plane/Master node should be ready."
echo "*********************************************************"
echo "GETTING ALL NODES WITH KUBECTL"
kubectl get nodes 
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "23) Check systemd Units for no crashlooping"
echo "*********************************************************"
echo "OBTAINING STATUS OF kubelet.service"
systemctl status kubelet.service 
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "24) Check Static Pod manifests."
echo "*********************************************************"
echo "LISTING DIR FOR ALL MANIFEST: /etc/kubernetes/manifests"
ls /etc/kubernetes/manifests
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "25) Checking API server and etcd's manifest."
echo "*********************************************************"
echo "REVIEWING INFORMATION OF /etc/kubernetes/manifests/etcd.yaml:"
cat /etc/kubernetes/manifests/etcd.yaml
echo ""

echo "REVIEWING INFORMATION OF /etc/kubernetes/manifests/kube-apiserver.yaml:"
cat /etc/kubernetes/manifests/kube-apiserver.yaml
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "26) Check out the directory where the kubeconfig files live for each of the control plane pods."
echo "*********************************************************"
echo "LISTING DIR FOR ALL /etc/kubernetes:"
ls /etc/kubernetes
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "27) Create tockens for the nodes."
echo "*********************************************************"
echo "CREATING TOKEN FOR NODE1 AND SAVING IT TO A TXT FILE."
kubeadm token create --print-join-command >> $HOME/join_k8_nodes.txt
echo "*********************************************************"
echo "*********************************************************"
echo ""

echo "*********************************************************"
echo "** EXTRA ** Enable bash auto-complete of our kubectl commands."
echo "*********************************************************"
apt-get install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc

echo "*********************************************************"
end_time=`date +%s`
runtime=$(((end_time-initial_time)/60))
echo "FINISHED PLANE-NODE.SH with $runtime minutes."
echo "*********************************************************"