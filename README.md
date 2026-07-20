# Infrastructure Provisioning and Application Deployment Using Terraform, Ansible & Jenkins

An end-to-end **DevOps automation project** that provisions AWS infrastructure using **Terraform**, configures servers and deploys a monolithic application using **Ansible**, and orchestrates the entire workflow through a **Jenkins CI/CD pipeline**.

This project demonstrates core DevOps practices — **Infrastructure as Code (IaC)**, **Configuration Management (CM)**, and **Continuous Integration / Continuous Deployment (CI/CD)** — to deliver infrastructure and applications in a way that is repeatable, consistent, scalable, and reliable.

---

## Project Overview

The goal of this project is to eliminate manual infrastructure setup and application deployment by automating the entire process end-to-end:

1. **Provision** the required AWS infrastructure (compute, storage, and access control) using Terraform.
2. **Configure** the provisioned servers and deploy the application onto them using Ansible.
3. **Orchestrate** the provisioning and deployment steps through a single automated Jenkins pipeline, triggered with one click (or on every code change).

This mirrors a real-world DevOps workflow where infrastructure changes and application deployments are version-controlled, automated, and auditable — removing manual, error-prone steps from the release process.

---

## Technology Details

### Tools

#### 🔧 Terraform
[Terraform](https://www.terraform.io/) is an open-source **Infrastructure as Code (IaC)** tool by HashiCorp that lets you define and provision cloud infrastructure using a declarative configuration language (**HCL – HashiCorp Configuration Language**).

**Role in this project:**
- Defines all AWS resources (EC2 instance, security groups, IAM roles/policies, S3 bucket) as code inside `.tf` files (`main.tf`, `provider.tf`, `s3.tf`, `security.tf`).
- `terraform init` initializes the working directory and downloads the required AWS provider plugins.
- `terraform plan` generates an execution plan showing what will be created, changed, or destroyed.
- `terraform apply` / `terraform destroy` (invoked via the `$action` variable in the pipeline) provisions or tears down the infrastructure.
- Maintains a **state file** to track the real-world resources it manages, enabling safe, incremental, and repeatable infrastructure changes.

**Why it's used:** Eliminates manual, click-ops provisioning in the AWS console; every infrastructure change is version-controlled, peer-reviewable, and reproducible.

#### 🔧 Ansible
[Ansible](https://www.ansible.com/) is an open-source **configuration management and application deployment tool**. It is **agentless** (works over SSH, no software needs to be installed on target machines) and uses simple, human-readable **YAML playbooks**.

**Role in this project:**
- Uses the **AWS EC2 dynamic inventory plugin** (`aws_ec2.yml`) to automatically discover the EC2 instance(s) that Terraform just created — no need to manually maintain a static list of server IPs.
- Runs the `deployment.yml` playbook located in the `ansible/` directory to:
  - Install required packages/dependencies on the EC2 instance.
  - Configure the server environment.
  - Deploy and start the monolithic application.
- Ensures **idempotency** — running the playbook multiple times produces the same consistent end state, without unwanted side effects.

**Why it's used:** Automates repetitive server configuration and deployment tasks, ensuring every environment is configured identically and reducing "it works on my machine" issues.

#### 🔧 Jenkins
[Jenkins](https://www.jenkins.io/) is an open-source **automation server** widely used to build **CI/CD pipelines**. It supports "Pipeline as Code" using a `Jenkinsfile`.

**Role in this project:**
- Acts as the **orchestrator** that ties Terraform and Ansible together into a single automated workflow.
- The declarative pipeline (see [Jenkins CI/CD Pipeline](#jenkins-cicd-pipeline) below) is defined in a `Jenkinsfile` with the following stages:
  - **Code** – Pulls the latest source from the GitHub repository.
  - **Init** – Initializes Terraform.
  - **Plan** – Generates the Terraform execution plan.
  - **Action** – Applies or destroys infrastructure based on a build parameter.
  - **Deploy** – Runs the Ansible playbook against the newly provisioned instance(s).
- Uses the `post { always { ... } }` block to send **Slack notifications** with the build status (`SUCCESS`/`FAILURE`), job name, build number, and a link to the build, regardless of the outcome.

**Why it's used:** Provides a single, repeatable, auditable trigger point for the entire infrastructure-to-deployment lifecycle, with built-in logging, history, and notifications.

---

### AWS Services

#### ☁️ Amazon EC2 (Elastic Compute Cloud)
[Amazon EC2](https://aws.amazon.com/ec2/) provides resizable virtual servers (instances) in the cloud.

**Role in this project:**
- Hosts the deployed monolithic application.
- Provisioned entirely through Terraform (`main.tf`), including the instance type, AMI, key pair, and networking configuration.
- Discovered dynamically by Ansible's EC2 inventory plugin so the playbook always targets the current, correct instance(s) without hardcoding IPs.

#### ☁️ AWS IAM (Identity and Access Management)
[AWS IAM](https://aws.amazon.com/iam/) is used to securely control access to AWS resources by managing users, groups, roles, and permission policies.

**Role in this project:**
- Provides the credentials/roles that allow Terraform (running from Jenkins) to authenticate and provision AWS resources securely.
- Defines least-privilege IAM policies/roles so that only the necessary permissions (e.g., EC2 provisioning, S3 access) are granted to the automation pipeline.
- Helps enforce security best practices by avoiding the use of long-lived root credentials in automation scripts.

#### ☁️ Amazon S3 (Simple Storage Service)
[Amazon S3](https://aws.amazon.com/s3/) is a highly durable and scalable object storage service.

**Role in this project:**
- Defined in `s3.tf`, used within the project for storage purposes such as holding Terraform-managed artifacts/state-related data or application assets used during deployment.
- Offers durability, versioning, and secure access controls, making it a reliable backing store as part of the infrastructure.

---

## Jenkins CI/CD Pipeline

The Jenkins pipeline automates the full provisioning-to-deployment workflow in five stages:

```groovy
pipeline {
    agent any 
    
    stages {
        stage ("Code") {
            steps {
                git branch: 'main', url: 'https://github.com/Krish951565/devops18.git'
            }
        }
        stage ("Init") {
            steps {
                sh 'echo -e "yes\n" | terraform init'
            }
        }
        stage ("Plan") {
            steps {
                sh 'terraform plan'
            }
        }
        stage ("Action") {
            steps {
                sh 'terraform $action --auto-approve'
            }
        }
        stage ("Deploy") {
            steps {
                sh 'ansible-playbook -i /opt/ansible/inventory/aws_ec2.yml ansible/deployment.yml'
            }
        }
    }
    post {
        always {
            echo 'Slack Notifications'
            slackSend (
                channel: 'myproject', message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} \n build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}" )
        }
    }
}
```

**Stage-by-stage breakdown:**

| Stage | Purpose |
|-------|---------|
| **Code** | Clones the latest source code from the GitHub repository (`main` branch). |
| **Init** | Initializes the Terraform working directory and downloads required providers. |
| **Plan** | Generates and displays the Terraform execution plan before any changes are applied. |
| **Action** | Runs `terraform apply` or `terraform destroy` based on the `action` build parameter, provisioning or tearing down AWS infrastructure. |
| **Deploy** | Runs the Ansible playbook using the AWS EC2 dynamic inventory to configure the server and deploy the application. |
| **Post (always)** | Sends a Slack notification with the build status, job name, build number, and build URL — for both successful and failed runs. |

**Key parameter:**
- `action` — a Jenkins build parameter (e.g., `apply` or `destroy`) that controls whether the **Action** stage provisions or destroys the AWS infrastructure, allowing the same pipeline to be reused for both deployment and cleanup.

---

## Prerequisites

Before running this project, ensure you have:

- An **AWS account** with an IAM user/role that has permissions for EC2, IAM, and S3.
- **AWS CLI** configured with valid credentials (`aws configure`).
- **Terraform** installed (v1.x recommended).
- **Ansible** installed, with the `amazon.aws` collection for the EC2 dynamic inventory plugin.
- **Jenkins** installed and configured with:
  - Terraform and Ansible available on the Jenkins agent (`PATH`).
  - Git plugin (to pull source code).
  - Slack Notification plugin + a configured Slack workspace/channel (`myproject`).
  - Credentials configured for AWS access (e.g., via environment variables or an IAM instance profile on the Jenkins server).
- An SSH key pair for Ansible to connect to the provisioned EC2 instance(s).

---

## Setup & Usage

1. **Clone the repository**
   ```bash
   git clone https://github.com/Krish951565/Infrastructure-Provisioning-and-Application-Deployment-Using-Terraform-Ansible-Jenkins.git
   cd Infrastructure-Provisioning-and-Application-Deployment-Using-Terraform-Ansible-Jenkins
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   ```

3. **Review/update Terraform variables**
   Update `provider.tf` / `main.tf` as needed (region, instance type, key pair name, etc.).

4. **Set up the Jenkins pipeline**
   - Create a new Jenkins Pipeline job.
   - Point it to this repository's `Jenkinsfile`.
   - Add a build parameter named `action` (choice/string) with values such as `apply` or `destroy`.
   - Configure Slack notification credentials in Jenkins.

5. **Run the pipeline**
   - Trigger the Jenkins job with `action = apply` to provision infrastructure and deploy the application.
   - Trigger the Jenkins job with `action = destroy` to tear down the infrastructure once you're done.

6. **Verify deployment**
   - Check the EC2 instance's public IP (from Terraform output or the AWS console).
   - Access the deployed application via the browser/port configured in the Ansible playbook.

---

## Key Learnings

- Writing modular, reusable Terraform configurations to provision AWS infrastructure.
- Using Ansible's dynamic inventory to configure infrastructure that doesn't have static, predictable IP addresses.
- Building a multi-stage declarative Jenkins pipeline to fully automate the provision → deploy lifecycle.
- Applying IAM least-privilege principles to secure automated infrastructure changes.
- Integrating build notifications (Slack) into a CI/CD pipeline for real-time visibility into deployment status.

---

## Author

**Krish951565**
GitHub: [Krish951565](https://github.com/Krish951565)
