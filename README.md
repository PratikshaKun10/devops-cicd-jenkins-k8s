Good question 👍. For a **clean GitHub DevOps project**, you should organize the repo properly and use a **separate branch** for development. This makes the project look **professional for interviews**.

I’ll give you:

1️⃣ Repository structure
2️⃣ Branch strategy
3️⃣ Exact folder paths
4️⃣ File contents
5️⃣ Git commands to push to GitHub

---

# 1️⃣ Create GitHub Repository

Create repo:

```
devops-cicd-jenkins-k8s
```

Then clone it:

```bash
git clone https://github.com/<your-username>/devops-cicd-jenkins-k8s.git
cd devops-cicd-jenkins-k8s
```

---

# 2️⃣ Branch Strategy

Use **two branches**

```
main        → stable project
feature/devops-pipeline   → development work
```

Create new branch:

```bash
git checkout -b feature/devops-pipeline
```

---

# 3️⃣ Project Folder Structure

Create folders:

```
devops-cicd-jenkins-k8s
│
├── terraform
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── app
│   ├── Dockerfile
│   └── index.html
│
├── k8s
│   ├── deployment.yaml
│   └── service.yaml
│
├── jenkins
│   └── Jenkinsfile
│
├── scripts
│   └── install_tools.sh
│
└── README.md
```

Create directories:

```bash
mkdir terraform app k8s jenkins scripts
```

---

# 4️⃣ Terraform Files

## terraform/main.tf

```hcl
provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "jenkins_server" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "jenkins-devops-server"
  }
}
```

---

## terraform/variables.tf

```hcl
variable "region" {
  default = "ap-south-1"
}
```

---

## terraform/outputs.tf

```hcl
output "instance_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}
```

---

# 5️⃣ Application Files

## app/index.html

```html
<!DOCTYPE html>
<html>
<head>
<title>DevOps CI/CD Project</title>
</head>

<body>

<h1>DevOps Pipeline Project</h1>
<p>Application deployed using Jenkins, Docker and Kubernetes</p>

</body>
</html>
```

---

## app/Dockerfile

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

---

# 6️⃣ Kubernetes Files

## k8s/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment

spec:
  replicas: 2

  selector:
    matchLabels:
      app: webapp

  template:
    metadata:
      labels:
        app: webapp

    spec:
      containers:
      - name: webapp
        image: <dockerhub-username>/webapp:latest

        ports:
        - containerPort: 80
```

---

## k8s/service.yaml

```yaml
apiVersion: v1
kind: Service

metadata:
  name: webapp-service

spec:
  selector:
    app: webapp

  ports:
  - port: 80
    targetPort: 80

  type: NodePort
```

---

# 7️⃣ Jenkins Pipeline

## jenkins/Jenkinsfile

```groovy
pipeline {

agent any

stages {

stage('Clone Repo') {

steps {

git 'https://github.com/<your-username>/devops-cicd-jenkins-k8s.git'

}

}

stage('Build Docker Image') {

steps {

sh 'docker build -t <dockerhub-username>/webapp ./app'

}

}

stage('Push Image') {

steps {

sh 'docker push <dockerhub-username>/webapp'

}

}

stage('Deploy to Kubernetes') {

steps {

sh 'kubectl apply -f k8s/deployment.yaml'
sh 'kubectl apply -f k8s/service.yaml'

}

}

}

}
```

---

# 8️⃣ Script to Install Tools on EC2

## scripts/install_tools.sh

```bash
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
```

---

# 9️⃣ README.md

Your README should include:

```
Project Overview
Architecture
Tools Used
CI/CD Pipeline Flow
Setup Instructions
Screenshots
```

Example architecture:

```
Developer → GitHub → Jenkins → Docker → DockerHub → Kubernetes
``
