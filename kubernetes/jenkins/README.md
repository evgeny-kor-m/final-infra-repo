## Jenkins
https://www.jenkins.io/doc/book/installing/kubernetes/
https://github.com/scriptcamp/kubernetes-jenkins  
https://devopscube.com/setup-jenkins-on-kubernetes-cluster/  
```
1. Create a Namespace
2. Create a service account with Kubernetes admin permissions.
3. Create local persistent volume for persistent Jenkins data on Pod restarts.
4. Create a deployment YAML and deploy it.
5. Create a service YAML and deploy it.
```
# Run
```
  kubectl apply -f kubernetes/jenkins -n jenkins-ns
  kubectl rollout restart statefulset/jenkins -n jenkins-ns
  kubectl -n jenkins-ns get all,secrets,svc,configmap

  kubectl exec jenkins-0  -n jenkins-ns -- cat /var/jenkins_home/secrets/initialAdminPassword
  b92ec6fc4a204730b2d12a997cccd002

http://localhost:30003
admin/admin  
```
### Access to GitHub Repo
PAT on GitHub / Frontend / Backend for CI  
Repositories:  
├── Metadata    -> Read-only   
├── Contents    -> Read and Write access to code  
└── Webhooks    -> Read-only   

### Add credential to Jenkins
```
Dashboard → Manage Jenkins → Credentials
  ↓
System → Global credentials → Add Credentials
Fill in:
- Kind: Username with password
- Username: your GitHub username
- Password: your Personal Access Token (which you created earlier)
- ID: github-frontend-cred
Save

github-frontend-cred   /   github-backend-cred   /   github-infra-cred
```
### Create nexus-registry secret 
```
kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-service.nexus-ns.svc.cluster.local:8083 \
  --docker-username=admin \
  --docker-password=nexusadmin \
  -n jenkins-ns
```
### Create Docker image based on Alpine OS for the Jenkins Slave
```
docker build --no-cache --provenance=false -t jenkins-inbound-agent-image:v7 -f ./kubernetes/jenkins/Dockerfile .

# Push to Nexus
kubectl port-forward svc/nexus-service 8082:8081 8083:8083 -n nexus-ns --address=0.0.0.0

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag jenkins-inbound-agent-image:v7  172.26.13.131:8083/jenkins-inbound-agent-image:v7
docker push 172.26.13.131:8083/jenkins-inbound-agent-image:v7
```
#### Configure Ngrok  
install ngrok in order to create static IP and proxy to your computer.   
https://ngrok.com/download/windows?tab=download   

registrate   

- run ngrok.exe     
- ngrok config add-authtoken 3BfhaedAenZ3lAuY3KY5viQIIIF_7ixX7TgMjGArTTt7rFNFb   
- Extra Port Mappings for Jenkins is - 30003    
```
ngrok http 30003

RES: Forwarding    https://lightless-rocco-climacterically.ngrok-free.dev -> http://localhost:30003  
```
#### Configure github webhook on Push event for frontend/backend repo
Trigger: PUSH → DEV branch   
github > (Reposirory) > settings > webhooks > Add webhook    
```
Fill:  
- Payload URL: <url from ngrok Forwarding> https://lightless-rocco-climacterically.ngrok-free.dev <and> /generic-webhook-trigger/ <and> /invoke?token=build-token
- Content type: application/json
- Let me select individual events: Pushes
- [v] Active  
```
#### Generic Webhook Trigger Plugin:
// Automated: Manage Jenkins → Plugins → Generic Webhook Trigger

#### CI Pipeline that builds and pushes a Docker image to Nexus
Configure the Job in Jenkins to catch webhook only 
```
Dashboard -> ci_pipeline -> Configure
Triggers:
→ [v] Generic Webhook Trigger
→ Token: build-token
Pipeline -> Definition -> Pipeline script from SCM
Fill:
- SCM -> Git
- Repository URL -> https://github.com/evgeny-kor-m/final-infra-repo.git  
- Credentials -> select (github-infra-cred)    
- Branch -> */main
- Script Path -> pipelines/build.Jenkinsfile
```
### Kubernetes with Jenkins Dynamic Agents
Dynamic Agents: Agents are Kubernetes pods that vanish after jobs finish. No more paying for idle VMs!   
Auto-Scaling: Need 10 agents at 2 PM and zero at 2 AM? Kubernetes handles it. (optional)   
Consistent Environments: Every job runs in a fresh, Dockerized workspace.   
#### Connect Jenkins to Kubernetes
Jenkins configurations:  
```
- Manage Jenkins → Nodes → Built-In Node → Configure
→ Number of executors: 0   
→ Save

// Automated:
- Manage Jenkins → Plugins → Available  
  → install 'Kubernetes' Plugin  
  → Restart Jenkins  

- Prerequisites & Cluster Role-based access control (RBAC):  Jenkins needs explicit permissions to interact with your cluster's API to spin up and terminate agent pods.  
Create a service account, role, and role binding inside your dedicated Jenkins namespace.  

# Configure Jenkins Cloud Provider - [Jenkins] → [kube-kind (Cloud)] → [Kubernetes API]:  
- Manage Jenkins > Clouds > New Cloud.
  → Type: kube-kind
  → Kubernetes URL: https://kubernetes.default.svc
  → Kubernetes Namespace: jenkins-ns
  → Jenkins URL: http://jenkins-service.jenkins-ns.svc.cluster.local:8080
  → Jenkins tunnel: jenkins-service.jenkins-ns.svc.cluster.local:50000
  → Concurrency Limit: 2     # The maximum number of concurrently running agent pods that are permitted in this Kubernetes Cloud
  → Test Connection  -> Connected to Kubernetes v1.31.0
  → Restart Jenkins
```
#### Build.Jenkinsfile 
```
# All changes in triggers {} need Run the Job manually once to re-read the Jenkinsfile
pipeline {
    agent { kubernetes {  yaml """ .....  """ }  }
    
    triggers {
        GenericTrigger(           # to catch webhook plybook
            genericVariables: [
                [key: 'REPO_NAME', value: '$.repository.name'],
                [key: 'REPO_URL',  value: '$.repository.clone_url'],
                [key: 'BRANCH',    value: '$.ref']
            ],
            token: 'build-token',  
            causeString: 'Triggered by $REPO_NAME'
        )
    }
}

# For debuging:
GitHub Redeliver:
GitHub -> repo -> Settings -> Webhooks
-> click webhook -> Recent Deliveries
-> click delivery -> Redeliver <---- will resend the same payload!

# same request
curl -X POST "https://lightless-rocco-climacterically.ngrok-free.dev/generic-webhook-trigger/invoke?token=build-token" \
  -H "Content-Type: application/json" \
  -d '{
    "repository": {
      "name": "final-frontend-repo",
      "clone_url": "https://github.com/evgeny-kor-m/final-frontend-repo.git"
    },
    "ref": "refs/heads/DEV",
    "head_commit": {
      "id": "02d1cad44533452bd9192b35f4043fab7cfd33ff",
      "message": "test"
    }
  }'

Run the Job via the Jenkins API:
Jenkins UI → admin → Security → API Token → Add new Token
→ copy <api-token>
curl -X POST "http://localhost:30003/job/ci_pipeline/build"  --user admin:110fcf28b021007da3a20ce2c98a9a7733
```
##### Using Kaniko instead Docker for build and pushing image
Kaniko is an open-source tool from Google Cloud that allows you to build Docker images from a Dockerfile without using a Docker daemon or privileged (root) access.   
It runs inside a container (for example, in a Kubernetes pod), making it ideal for secure CI/CD environments.   

In Dockerfile agent:   
```
# Copy Kaniko executor from official image
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko /kaniko

ENV PATH=$PATH:/kaniko

# Create kaniko dir and fix permissions for root
RUN mkdir -p /kaniko/.docker && \
    chmod -R 777 /kaniko
```
Use nexus-registry-secret providing kaniko Nexus credentials:
```
kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-service.nexus-ns.svc.cluster.local:8083 \
  --docker-username=admin \
  --docker-password=nexusadmin \
  -n jenkins-ns
```
Deployment agent - mounted config.json:
```
volumeMounts:
- name: kaniko-secret
  mountPath: /kaniko/.docker/config.json
  subPath: config.json

volumes:
- name: kaniko-secret
  secret:
    secretName: nexus-registry-secret
    items:
    - key: .dockerconfigjson
      path: config.json
```
Jenkinsfile :
```
stage('Build & Push') {
    steps {
        sh """
            # Set Docker config path for Kaniko credentials (to allow Kaniko read config.json)
            export DOCKER_CONFIG=/kaniko/.docker

            # Copy to a separate folder outside the workspace for kaniko, because kaniko destroy filesystem
            cp -r \$(pwd) /tmp/build_context

            # Build and push image to Nexus
            /kaniko/executor \
                --context /tmp/build_context \   # workspace for kaniko
                --context . \                    # build context = current directory
                --dockerfile Dockerfile \        # Dockerfile location
                --destination nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA} \  # image:tag
                --insecure \                     # use HTTP instead of HTTPS
                --skip-tls-verify \              # skip TLS verification
        #---------optimizations----------------------------------------------------------------------------------------------------------------------          
                --cache=true \                   # enable layer caching (improving speed / reducing build time)
                --cache-repo=nexus-service.nexus-ns.svc.cluster.local:8083/kaniko-cache \  # cache storage  (improving speed / reducing build time)
                --snapshot-mode=redo             # [full] - checks ALL files, slow but accurate. [redo] - checks only modified files, faster
        """
    }
}
```
#### CD Pipeline that change image Tag and pushe to GitHub
```
Dashboard → cd-pipeline → Configure
Triggers: 'will started from ci-pipeline Jenkinsfile'

Pipeline → Definition → Pipeline script from SCM
Fill:
- SCM → Git
- Repository URL → https://github.com/evgeny-kor-m/final-infra-repo.git  
- Credentials → select (github-infra-cred)
- Branch → */main
- Script Path → pipelines/prepare.Jenkinsfile
```
#### prepare.Jenkinsfile
```
CD Pipeline:
  │
  ▼
1. git checkout cd/deployments
    git pull origin main ← sync with latest changes
  │
  ▼
2. sed → update image tag
  │
  ▼
3. git push origin cd/deployments
  │
  ▼
4. Open PR: cd/deployments → main
  │
  ▼
5. Auto-merge PR
  │
  ▼
main ← updated
```

### Email Extension Plugin 
```
Manage Jenkins → Plugins → "Email Extension"
Install

Basic SMTP setup (if you use Gmail)
First, get an App Password from Google:
myaccount.google.com → Security → 2-Step Verification (must be enabled)
→ App passwords → Generate → select "Mail" → copy the 16-digit password

SMTP is configured in 
Manage Jenkins → System → 
Extended E-mail Notification:
Field Value SMTP servers:  smtp.gmail.com 
SMTP Port 465 Use SMTP Authentication [v]  
User Name evgeny.korchev@gmail.com 
Password 16-character password (without spaces - Jenkins usually accepts both with and without spaces, but it's cleaner to insert them together) 
Use SSL [v]  
Default Content: Type HTML (text/html)
---
E-mail Notification: 
User Name evgeny.korchev@gmail.com
Password16-значный App Password 
Use SSL [v]  
Use TLSоставь empty
SMTP Port 465
Reply-To Address evgeny.korchev@gmail.com
Charsetоставь UTF-8
- Test configuration
``` 
### Trivy Image Scanner
https://medium.com/@lilnya79/integrating-jenkins-with-trivy-222eaa7a70be
