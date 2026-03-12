# DevOps CI/CD Pipeline — Jenkins + Docker + EKS

> Application deployed using Jenkins, Docker and Kubernetes on AWS EKS

---

## 🏗️ Project Structure

```
devops-cicd-jenkins-k8s/
├── app/
│   ├── Dockerfile
│   └── index.html
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── jenkins/
├── scripts/
└── README.md
```

---

## 🛠️ Prerequisites

- AWS Account with IAM credentials
- Terraform installed
- AWS CLI installed
- kubectl installed
- eksctl installed
- Docker installed
- Git

---

## 📋 Steps Completed

### Step 1: Provision Jenkins EC2 Server using Terraform

**Files:** `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`

The Terraform config creates:
- AWS Security Group with ports 22 (SSH), 8080 (Jenkins), 30000-32767 (NodePort)
- EC2 instance (t3.medium, Ubuntu, ap-south-1)

```bash
cd terraform/
terraform init
terraform plan
terraform apply --auto-approve

# Get EC2 public IP
terraform output instance_public_ip
```

---

### Step 2: Install Jenkins on EC2

SSH into EC2:
```bash
ssh -i ~/.ssh/aws.pem ubuntu@<EC2-PUBLIC-IP>
```

Install Java and Jenkins:
```bash
sudo apt update -y

# Install Java
sudo apt install fontconfig openjdk-21-jre -y

# Add Jenkins repo with correct key
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install jenkins -y

sudo systemctl start jenkins
sudo systemctl enable jenkins
```

Access Jenkins UI:
```
http://<EC2-PUBLIC-IP>:8080
```

Get initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

### Step 3: Install Required Tools on EC2

**AWS CLI:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

**Configure AWS credentials:**
```bash
aws configure
# Enter: Access Key, Secret Key, region: ap-south-1, output: json
```

**kubectl:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**eksctl:**
```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

**Docker:**
```bash
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
newgrp docker
```

---

### Step 4: Provision EKS Cluster using Terraform

**Files:** `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`, `terraform/versions.tf`

`versions.tf`:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }
  }
  required_version = ">= 1.3.0"
}
```

`main.tf` creates:
- VPC with public and private subnets across 2 AZs
- NAT Gateway
- EKS Cluster (v1.31)
- Managed Node Group (t3.medium, 2 nodes)

```bash
cd terraform/
terraform init
terraform plan
terraform apply --auto-approve
```

> ⏳ EKS cluster creation takes 15-20 minutes.

Connect kubectl to EKS:
```bash
aws eks update-kubeconfig --region ap-south-1 --name devops-eks-cluster
kubectl get nodes
```

---

### Step 5: Build & Push Docker Image to ECR

Create ECR repository:
```bash
aws ecr create-repository \
  --repository-name webapp \
  --region ap-south-1
```

Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS \
  --password-stdin <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com
```

Build, tag and push:
```bash
cd app/

docker build -t webapp:latest .

docker tag webapp:latest \
  <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/webapp:latest

docker push \
  <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/webapp:latest
```

---

### Step 6: Deploy Application to EKS

`k8s/deployment.yaml`:
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
        image: <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/webapp:latest
        ports:
        - containerPort: 80
```

`k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
```

Deploy:
```bash
cd k8s/
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Watch pods
kubectl get pods -w

# Get public URL
kubectl get svc webapp-service
```

---

## ✅ Final Result

Application is live and accessible via AWS Load Balancer URL:
```
http://<EXTERNAL-IP>.ap-south-1.elb.amazonaws.com
```

```
NAME             TYPE           EXTERNAL-IP                                PORT(S)
webapp-service   LoadBalancer   xxx.ap-south-1.elb.amazonaws.com          80:30112/TCP
```

---

## 🧹 Cleanup (To Avoid AWS Charges)

```bash
# Delete k8s resources
kubectl delete -f k8s/

# Destroy EKS cluster and VPC
cd terraform/
terraform destroy --auto-approve

# Terminate Jenkins EC2
# Go to AWS Console → EC2 → Terminate instance
```

---

## 🏛️ Architecture

```
Developer (Local WSL)
        ↓
   Terraform (EC2 + EKS)
        ↓
EC2 Jenkins Server
        ↓
Docker Build → Push to ECR
        ↓
kubectl apply → EKS Cluster
        ↓
AWS Load Balancer
        ↓
  App Live on Internet 🌐
```

---

## 🔧 Tech Stack

| Tool        | Purpose                        |
|-------------|-------------------------------|
| Terraform   | Infrastructure as Code         |
| AWS EC2     | Jenkins Server                 |
| Jenkins     | CI/CD Pipeline                 |
| Docker      | Containerization               |
| AWS ECR     | Container Registry             |
| AWS EKS     | Kubernetes Cluster             |
| kubectl     | Kubernetes CLI                 |
| eksctl      | EKS Cluster Management         |
| Nginx       | Web Server inside container    |
