# DevOps CI/CD Pipeline — Jenkins + Docker + EKS

> Application deployed using Jenkins, Docker and Kubernetes on AWS EKS

![Pipeline Status](https://img.shields.io/badge/Pipeline-Passing-brightgreen)
![Platform](https://img.shields.io/badge/Platform-AWS-orange)
![K8s](https://img.shields.io/badge/Kubernetes-EKS-blue)

---

##  Project Structure

```
devops-cicd-jenkins-k8s/
├── app/
│   ├── Dockerfile
│   └── index.html
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── jenkins/
│   └── Jenkinsfile
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── scripts/
└── README.md
```

---

##  Prerequisites

- AWS Account with IAM credentials
- Terraform >= 1.3.0
- AWS CLI v2
- kubectl
- eksctl
- Docker
- Git

---

##  Complete Setup Guide

---

### Step 1: Setup WSL DNS (Windows Users)

If running on WSL, fix DNS before starting:

```bash
# Fix DNS
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'

# Make permanent
sudo bash -c 'cat > /etc/wsl.conf << EOF
[network]
generateResolvConf = false
EOF'
```

From Windows PowerShell:
```powershell
wsl --shutdown
```

---

### Step 2: Install Terraform (WSL/Ubuntu)

```bash
# Download binary directly (avoid snap)
wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/terraform

# Add to PATH
export PATH=/usr/local/bin:$PATH
echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify
terraform version
```

---

### Step 3: Provision Jenkins EC2 Server using Terraform

Creates Security Group (ports 22, 8080, 30000-32767) and EC2 instance (t3.medium, Ubuntu, ap-south-1):

```bash
cd terraform/
terraform init
terraform plan
terraform apply --auto-approve

# Get EC2 public IP
terraform output instance_public_ip
```

---

### Step 4: Install Jenkins on EC2

SSH into EC2:
```bash
ssh -i ~/.ssh/aws.pem ubuntu@<EC2-PUBLIC-IP>
```

Install Java and Jenkins:
```bash
sudo apt update -y

# Install Java 21
sudo apt install fontconfig openjdk-21-jre -y

# Add Jenkins repo with correct 2026 key
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

Install suggested plugins when prompted.

---

### Step 5: Install Required Tools on EC2

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

# Verify
aws sts get-caller-identity
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

### Step 6: Provision EKS Cluster using Terraform

Pin AWS provider to v5 to avoid compatibility issues with EKS module v19:

**`terraform/versions.tf`:**
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

**`terraform/main.tf`** creates VPC, subnets, NAT Gateway, EKS Cluster, Node Group:
```bash
cd terraform/
terraform init
terraform plan
terraform apply --auto-approve
```

>  EKS cluster creation takes 15-20 minutes.

Connect kubectl to EKS:
```bash
aws eks update-kubeconfig --region ap-south-1 --name devops-eks-cluster
kubectl get nodes
```

---

### Step 7: Clone Repository on EC2

```bash
git clone https://github.com/PratikshaKun10/devops-cicd-jenkins-k8s.git
cd devops-cicd-jenkins-k8s
git checkout feature/devops-pipeline
```

---

### Step 8: Build and Push Docker Image to ECR

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
docker tag webapp:latest <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/webapp:latest
docker push <ACCOUNT-ID>.dkr.ecr.ap-south-1.amazonaws.com/webapp:latest
```

---

### Step 9: Deploy Application to EKS

**`k8s/deployment.yaml`:**
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

**`k8s/service.yaml`:**
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
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -w
kubectl get svc webapp-service
```

---

### Step 10: Setup Jenkins CI/CD Pipeline

Give Jenkins necessary permissions:
```bash
# Docker permissions
sudo usermod -aG docker jenkins
sudo chmod 777 /var/run/docker.sock
sudo systemctl restart jenkins

# AWS credentials for Jenkins
sudo mkdir -p /var/lib/jenkins/.aws
sudo cp ~/.aws/credentials /var/lib/jenkins/.aws/credentials
sudo cp ~/.aws/config /var/lib/jenkins/.aws/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.aws
sudo chmod 600 /var/lib/jenkins/.aws/credentials

# kubectl config for Jenkins
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config

sudo systemctl restart jenkins
```

Create Pipeline in Jenkins UI:
1. Jenkins Dashboard → **New Item**
2. Name: `webapp-pipeline` → Select **Pipeline** → Click **OK**
3. Under **Build Triggers** → Check **"GitHub hook trigger for GITScm polling"**
4. Under **Pipeline** → Definition: `Pipeline script` → Paste Jenkinsfile content
5. Click **Save** → **Build Now**

**`jenkins/Jenkinsfile`:**
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION       = 'ap-south-1'
        AWS_ACCOUNT_ID   = '697629626862'
        ECR_REPO         = 'webapp'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        FULL_IMAGE_NAME  = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        EKS_CLUSTER_NAME = 'devops-eks-cluster'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'feature/devops-pipeline',
                    url: 'https://github.com/PratikshaKun10/devops-cicd-jenkins-k8s.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${ECR_REPO}:${IMAGE_TAG} ./app
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${FULL_IMAGE_NAME}
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS \
                    --password-stdin ${ECR_REGISTRY}
                    docker push ${FULL_IMAGE_NAME}
                """
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh """
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${EKS_CLUSTER_NAME}
                    sed -i 's|image:.*|image: ${FULL_IMAGE_NAME}|g' k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl rollout status deployment/webapp-deployment
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                sh """
                    kubectl get pods
                    kubectl get svc webapp-service
                """
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed! App deployed successfully.'
        }
        failure {
            echo 'Pipeline failed! Check logs.'
        }
        always {
            sh """
                docker rmi ${FULL_IMAGE_NAME} || true
                docker rmi ${ECR_REPO}:${IMAGE_TAG} || true
            """
        }
    }
}
```

---

### Step 11: Configure GitHub Webhook for Auto-Trigger

Every push to GitHub automatically triggers the Jenkins pipeline.

**Add GitHub Personal Access Token to Jenkins:**
1. Go to `https://github.com/settings/tokens/new`
2. Select scopes: `repo` and `admin:repo_hook`
3. Click **Generate token** and copy it
4. In Jenkins → **Manage Jenkins** → **System** → **GitHub Servers** → **Add**
5. Kind: `Secret text` → paste token → ID: `github-token`
6. Select token in Credentials dropdown → **Test connection**

**Add Webhook in GitHub:**
1. Go to your repo → **Settings** → **Webhooks** → **Add webhook**
2. Fill in:
```
Payload URL:  http://<EC2-PUBLIC-IP>:8080/github-webhook/
Content type: application/json
Secret:       (leave empty)
Trigger:      Just the push event
```
3. Click **Add webhook**

**Verify Webhook is Working:**
```
GitHub → Settings → Webhooks → Click webhook → Recent Deliveries
✅ Green = webhook delivered successfully
```

**Test Auto-Trigger:**
```bash
echo "<!-- update -->" >> app/index.html
git add app/index.html
git commit -m "Update app"
git push origin feature/devops-pipeline
```

Jenkins pipeline triggers automatically on every push! 🚀

---

## ✅ Final Result

Application is live:
```
http://<EXTERNAL-IP>.ap-south-1.elb.amazonaws.com
```

---

##  Cleanup (To Avoid AWS Charges)

```bash
# Delete k8s resources
kubectl delete -f k8s/

# Destroy EKS + VPC
cd terraform/
terraform destroy --auto-approve

# Delete ECR repo
aws ecr delete-repository \
  --repository-name webapp \
  --region ap-south-1 \
  --force

# Terminate Jenkins EC2 from AWS Console
```

---

##  Architecture

```
Developer pushes code
        ↓
GitHub Repository
        ↓
GitHub Webhook → POST to Jenkins
        ↓
Jenkins (GitHub hook trigger)
        ↓
┌───────────────────────┐
│  Jenkins Pipeline     │
│  1. Checkout Code     │
│  2. Docker Build      │
│  3. Push to ECR       │
│  4. Deploy to EKS     │
│  5. Verify            │
└───────────────────────┘
        ↓
AWS ECR (Image Registry)
        ↓
AWS EKS (Kubernetes Cluster)
        ↓
AWS Load Balancer
        ↓
App Live on Internet 
```

---

##  Tech Stack

| Tool       | Purpose                    |
|------------|---------------------------|
| Terraform  | Infrastructure as Code     |
| AWS EC2    | Jenkins Server             |
| Jenkins    | CI/CD Pipeline             |
| Docker     | Containerization           |
| AWS ECR    | Container Registry         |
| AWS EKS    | Kubernetes Cluster         |
| kubectl    | Kubernetes CLI             |
| eksctl     | EKS Cluster Management     |
| Nginx      | Web Server in container    |
| GitHub Webhook | Auto pipeline trigger  |

---

##  Common Issues and Fixes

| Issue | Fix |
|-------|-----|
| DNS resolution failed on WSL | `echo "nameserver 8.8.8.8" > /etc/resolv.conf` |
| Terraform snap timeout on WSL | Install via binary download instead of snap |
| AWS provider v6 incompatible with EKS module | Pin to `~> 5.40.0` in versions.tf |
| Jenkins NoCredentials error | Copy `~/.aws` to `/var/lib/jenkins/.aws` |
| kubectl not found in Jenkins | Copy `~/.kube/config` to `/var/lib/jenkins/.kube/config` |
| Webhook not triggering pipeline | Enable anonymous read access in Jenkins Security settings |
| EKS node group AccessDenied | Run `aws iam create-service-linked-role --aws-service-name eks-nodegroup.amazonaws.com` |
