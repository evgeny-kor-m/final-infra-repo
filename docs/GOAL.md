# 🚀 Final Project – Kubernetes + Jenkins + ArgoCD + ELK

## 🎯 Project Overview

In this project you will build a complete cloud-native platform that includes:

* 🌐 Frontend Application
* ⚙️ Backend API
* 🗄 Database - create at least 2 users (ReadOnly, ReadWrite)
* 🐳 Docker - dont use root user - nice to have
* ☸️ Kubernetes
* 📦 Nexus Repository - (Bonus Scanner - ask Yakir 08/06)
* 🧪 Jenkins
* 🚀 ArgoCD
* 📊 ELK Stack
* 🗂 Git Workflow

The project is divided into **5 main parts**.

---

# 📦 Part 1 – Three-Tier Application (20 Points)

## 🎯 Objective

Build a complete hotel reservation system using a three-tier architecture.

---

## 🌐 Layer 1 – Frontend Application

### Requirements

Develop a frontend application using:

* JavaScript
* OR TypeScript

The application must contain multiple screens.

---

### Screen 1 – New Reservation

The user must:

* Select a hotel from the available list
* Enter:

  * Full Name
  * Email Address
  * Check-In Date
  * Check-Out Date

If the selected dates are available, the user should receive a confirmation message indicating that the reservation was successfully completed.

---

### Screen 2 – Reservation Lookup

The user must:

* Enter Full Name or Email Address

The application should:

* Retrieve reservation details from the database
* Display reservation information if found
* Allow the user to cancel the reservation

---

## ⚙️ Layer 2 – Backend Application

### Requirements

Develop a backend application using:

* JavaScript
* OR Python

---

### Function 1 – Create Reservation (ReadWrite User)

The backend must:

* Validate reservation details
* Verify business rules
* Store reservation data in the database
* Return a success message

---

### Function 2 – Reservation Lookup (ReadOnly User)

The backend must:

* Receive a Reservation ID
* Verify the reservation exists
* Return reservation details

---

### Function 3 – Cancel Reservation (ReadWrite User)

The backend must:

* Receive a Reservation ID
* Verify the reservation exists
* Remove the reservation from the database
* Return a cancellation confirmation

---

## 🗄 Layer 3 – Database

You may choose:

* MySQL
* OR MongoDB

---

### Table / Collection 1 – Hotels

Each hotel must contain:

```text
Hotel ID
Hotel Name
Description
Location
Price Per Night
```

---

### Table / Collection 2 – Reservations

Each reservation must contain:

```text
Reservation ID
Full Name
Email Address
Check-In Date
Check-Out Date
Hotel ID
```

---

### Database Client UI

You must deploy a database client UI based on your selected database.

Examples:

* Mongo Express
* phpMyAdmin
* Adminer

---

# ☸️ Part 2 – Deployment & Artifact Registry (20 Points)

## 🎯 Objective

Deploy the entire platform into a local Kubernetes cluster and implement artifact registry.

---

## 🚀 Deployment Requirements

Supported platforms:

* Minikube
* Kind
* Docker Desktop Kubernetes

---

### Kubernetes Requirements

Deploy all components from Part 1.

Use:

* Dedicated Namespaces
* Persistent Volumes
* ConfigMaps
* Secrets

---

### Replica Requirements

#### Frontend

```text
5 Replicas
```

#### Backend

```text
5 Replicas
```

#### Database

```text
3 Replicas
```

---

## 📦 Artifact Registry Requirements

Deploy a local Nexus Repository inside Kubernetes.

---

### Nexus Requirements

Use:

* Dedicated Namespace
* Persistent Volumes
* ConfigMaps
* Secrets

Nexus will serve as the private container registry for the project.

---

# 🧪 Part 3 – Build Process (20 Points)

## 🎯 Objective

Deploy Jenkins and automate the build process.

---

## 📌 Requirements

Deploy:

* Jenkins Master
* Jenkins Agents

Use:

* Dedicated Namespace
* Persistent Volumes
* ConfigMaps
* Secrets

---

## ⚙️ Pipeline 1 – Build Pipeline

### Trigger

```text
PUSH → DEV Branch
```

### Responsibilities

1. Build application artifacts
2. Build Docker images
3. Push images to Nexus Repository

---

## ⚙️ Pipeline 2 – Deployment Preparation Pipeline

### Trigger

```text
After Build Pipeline Completes
```

### Responsibilities

1. Update image tag references
2. Replace old image version with new version
3. Open Pull Request to MAIN
4. Approve Pull Request
5. Merge Pull Request

---

## ⚠️ Dynamic Agent Requirement

Jenkins must use Kubernetes Dynamic Agents.

Expected behavior:

```text
Pipeline Starts
↓
Agent Created
↓
Pipeline Executes
↓
Agent Deleted
```

Static agents are not allowed.

---

## 🔐 Repository Authentication

Connect GitHub using:

* SSH Keys
* OR Personal Access Token (PAT)

---

# 🚀 Part 4 – Deployment Process (20 Points)

## 🎯 Objective

Deploy applications automatically using ArgoCD.

---

## 📌 Requirements

Deploy ArgoCD using:

* Dedicated Namespace
* Persistent Volumes
* ConfigMaps
* Secrets

---

## Application 1 – Frontend

### Trigger

```text
Changes in MAIN Branch
```

### Responsibilities

* Detect manifest changes
* Deploy frontend updates automatically

---

## Application 2 – Backend

### Trigger

```text
Changes in MAIN Branch
```

### Responsibilities

* Detect manifest changes
* Deploy backend updates automatically

---

## 🔐 Repository Authentication

Connect GitHub using:

* SSH Keys
* OR Personal Access Token (PAT)

---

# 📊 Part 5 – Monitoring Platform (20 Points)

## 🎯 Objective

Deploy a complete monitoring and observability solution.

---

## 📌 Requirements

Deploy ELK Stack inside Kubernetes.

### Components

* Elasticsearch
* Logstash
* Kibana

---

### Deployment Requirements

Use:

* Dedicated Namespace
* Persistent Volumes
* ConfigMaps
* Secrets

---

## Monitoring Requirements

The platform must collect:

### Metrics

Collect metrics from all Kubernetes components.

### Logs

Collect logs from:

* Frontend
* Backend
* Database
* Jenkins
* ArgoCD
* Nexus

### Traces

Collect traces across the platform.

---

## Validation

Demonstrate monitoring in real time.

---

# 🔐 Git Requirements

* Create a 3 Private Repositories

Branch strategy:

```text
MAIN → Production
DEV → Development
```

* Work ONLY on DEV
* Open Pull Requests to MAIN

---

## 👤 Add Collaborator

You must add:

* Email: [yakirbar7820@gmail.com](mailto:yakirbar7820@gmail.com)
* GitHub: [https://github.com/YakirBar](https://github.com/YakirBar)

Only after PR approval will it be merged into MAIN.

---

# 📁 Recommended Folder Structure

```text
frontend-repo/
│
├── src/
├── Dockerfile
└── README.md

backend-repo/
│
├── src/
├── Dockerfile
└── README.md

infra-repo/
│
├── kubernetes/
│   ├── secrets/
│   ├── volumes/
│   ├── services/
│   └── deployments/
│
├── pipelines/
│   ├── build.Jenkinsfile
│   └── prepare.Jenkinsfile
│
├── argocd/
│   ├── frontend-app.yaml
│   └── backend-app.yaml
│
└── README.md
```

---

# 📋 Mandatory Files for Submission

* Dockerfile – Frontend
* Dockerfile – Backend
* Kubernetes Manifests
* Nexus Deployment Files
* Jenkins Deployment Files
* Build Pipeline
* Deployment Preparation Pipeline
* ArgoCD Frontend Application
* ArgoCD Backend Application
* ELK Deployment Files
* README.md
* Architecture Diagram

---

# 🧮 Grading Breakdown

| Section                                 | Points |
| --------------------------------------- | ------ |
| Part 1 – Three-Tier Application         | 20     |
| Part 2 – Deployment & Artifact Registry | 20     |
| Part 3 – Build Process                  | 20     |
| Part 4 – Deployment Process             | 20     |
| Part 5 – Monitoring Platform            | 20     |

---

# ⚠️ Important Technical Requirements

## 🔐 Security

* Use Kubernetes Secrets
* Use Jenkins Credentials
* No hardcoded credentials
* Use ConfigMaps for non-sensitive configuration

---

## ☸️ Kubernetes

* Use dedicated namespaces
* Use Persistent Volumes
* Use ConfigMaps
* Use Secrets
* Maintain required replica counts

---

## 🔁 Best Practices

* Use meaningful resource names
* Maintain clean folder structure
* Follow GitOps principles
* Separate infrastructure and application resources

---

# 💡 Expected Skills

This project simulates a real-world enterprise DevOps platform including:

* Frontend Development
* Backend Development
* Database Management
* Kubernetes Administration
* CI/CD Automation
* GitOps Workflows
* Artifact Management
* Monitoring & Observability

---

# 🌐 Allowed & Forbidden Resources

## ✅ Allowed Resources

* GitHub
  [https://github.com](https://github.com)

* Docker Hub
  [https://hub.docker.com](https://hub.docker.com)

* Kubernetes Documentation
  [https://kubernetes.io/docs](https://kubernetes.io/docs)

* Jenkins Documentation
  [https://www.jenkins.io](https://www.jenkins.io)

* ArgoCD Documentation
  [https://argo-cd.readthedocs.io](https://argo-cd.readthedocs.io)

* Nexus Documentation
  [https://help.sonatype.com](https://help.sonatype.com)

* Elastic Documentation
  [https://www.elastic.co/guide](https://www.elastic.co/guide)

* Stack Overflow
  [https://stackoverflow.com/questions](https://stackoverflow.com/questions)

---

## ❌ Forbidden Resources

* Any AI chat tools
* Any AI code generation platforms
* Any automated DevOps code builders

All work must be completed independently using documentation and your own understanding.

Violation of this rule may result in disqualification.

---

Bonus Task: Security Image Scanner Integration with NexusHub

Add an image scanning capability integrated with NexusHub that automatically triggers on every push request in the CI/CD pipeline.

Requirements:
Implement an image scanning service connected to NexusHub.
Trigger the scan automatically on every push request (CI pipeline hook).
Analyze uploaded images/artifacts for vulnerabilities or security risks.
If a high-severity vulnerability is detected:
Send an email notification to yourself.
Fail the pipeline immediately and prevent further execution.
Ensure the scanning step is fully integrated into the existing pipeline flow.

---

Bonus Task: Secret Manager Tool Integration with Kubernetes

Deploy a centralized secret management service (e.g., OpenBao) inside the Kubernetes cluster and use it to manage application secrets instead of static Kubernetes Secrets.

Requirements:
Deploy OpenBao (or another compatible secret manager) into the Kubernetes cluster using Helm or manifests.
Configure authentication between Kubernetes and the secret manager.
Store application credentials (database passwords, API keys, etc.) in the secret manager.
Inject secrets into workloads.
Enable automatic password rotation every 1 day (24 hours).
Ensure rotated secrets are synchronized to running applications without manual intervention.
