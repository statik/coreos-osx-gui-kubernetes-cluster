#!/bin/bash

#  vagrant_up.command
#  CoreOS Kubernetes Cluster for OS X
#
#  Created by Rimantas on 01/12/2014.
#  Copyright (c) 2014 Rimantas Mocevicius. All rights reserved.

# path to the bin folder where we store our binary files
export PATH=${HOME}/coreos-k8s-cluster/bin:$PATH

# set etcd endpoint
export ETCDCTL_PEERS=http://172.17.15.101:4001

# set fleetctl endpoint
export FLEETCTL_ENDPOINT=http://172.17.15.101:4001
export FLEETCTL_STRICT_HOST_KEY_CHECKING=false
#

# set kubernetes master
export KUBERNETES_MASTER=http://172.17.15.101:8080
#

cd ~/coreos-k8s-cluster/control
machine_status=$(vagrant status | grep -o -m 1 'not created')

if [ "$machine_status" = "not created" ]
then
    vagrant up --provider virtualbox
    #
    cd ~/coreos-k8s-cluster/workers
    vagrant up --provider virtualbox

    # Add vagrant ssh key to ssh-agent
    ssh-add ~/.vagrant.d/insecure_private_key >/dev/null 2>&1

    # install k8s files on master
    echo " "
    echo " Installing k8s files to master and nodes:"
    cd ~/coreos-k8s-cluster/control
    vagrant scp master.tgz /home/core/
    vagrant ssh k8smaster-01 -c "sudo /usr/bin/mkdir -p /opt/bin && sudo tar xzf /home/core/master.tgz -C /opt/bin && sudo chmod 755 /opt/bin/* && ls -alh /opt/bin " >/dev/null 2>&1

    # install k8s files on nodes
    cd ~/coreos-k8s-cluster/workers
    vagrant scp nodes.tgz /home/core/
    #
    vagrant ssh k8snode-01 -c "sudo /usr/bin/mkdir -p /opt/bin && sudo tar xzf /home/core/nodes.tgz -C /opt/bin && sudo chmod 755 /opt/bin/* && ls -alh /opt/bin " >/dev/null 2>&1
    vagrant ssh k8snode-02 -c "sudo /usr/bin/mkdir -p /opt/bin && sudo tar xzf /home/core/nodes.tgz -C /opt/bin && sudo chmod 755 /opt/bin/* && ls -alh /opt/bin " >/dev/null 2>&1
    echo "Done installing ... "

    # install fleet units
    echo " "
    echo "Installing fleet units:"
    cd ~/coreos-k8s-cluster/fleet
    fleetctl start *.service
    echo " "
    #
    echo Waiting for Kubernetes cluster to be ready. This can take a few minutes...
    spin='-\|/'
    i=0
    until ~/coreos-k8s-cluster/bin/kubectl version | grep 'Server Version' >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
    i=0
    until ~/coreos-k8s-cluster/bin/kubectl get nodes | grep 172.17.15.102 >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
    i=0
    until ~/coreos-k8s-cluster/bin/kubectl get nodes | grep 172.17.15.103 >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
    echo " "
    # attach label to the nodes
    ~/coreos-k8s-cluster/bin/kubectl label nodes 172.17.15.102 node=worker1
    ~/coreos-k8s-cluster/bin/kubectl label nodes 172.17.15.103 node=worker2
    echo " "
else
    vagrant up
    #
    cd ~/coreos-k8s-cluster/workers
    vagrant up
fi


#
echo "etcd cluster:"
etcdctl --no-sync ls /
echo ""
#
echo "fleetctl list-machines:"
fleetctl list-machines
echo " "
#
echo "fleetctl list-units:"
fleetctl list-units
echo " "
#
echo "kubectl get nodes:"
kubectl get nodes
echo " "

cd ~/coreos-k8s-cluster/kubernetes

# open bash shell
/bin/bash
