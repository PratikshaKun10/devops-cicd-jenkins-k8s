#!/bin/bash

sudo apt update -y

# install docker
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker

# install kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube