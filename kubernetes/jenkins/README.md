## Jenkins
https://www.jenkins.io/doc/book/installing/kubernetes/
https://github.com/scriptcamp/kubernetes-jenkins  
https://devopscube.com/setup-jenkins-on-kubernetes-cluster/  

1. Create a Namespace
2. Create a service account with Kubernetes admin permissions.
3. Create local persistent volume for persistent Jenkins data on Pod restarts.
4. Create a deployment YAML and deploy it.
5. Create a service YAML and deploy it.

# Run
```
  kubectl apply -f kubernetes/jenkins/jenkins-master -n jenkins-ns
  kubectl rollout restart statefulset/jenkins -n jenkins-ns

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
docker build -t jenkins-inbound-agent-image:latest -f ./kubernetes/jenkins/jenkins-slave/Dockerfile .

# Push to Nexus
kubectl port-forward svc/nexus-service 8082:8081 8083:8083 -n nexus-ns --address=0.0.0.0

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag jenkins-inbound-agent-image:latest  172.26.13.131:8083/jenkins-inbound-agent-image:latest 
docker push 172.26.13.131:8083/jenkins-inbound-agent-image:latest
```
#### Create & Configure new Inbound Agent 'Docker-Agent' in Jenkins
Jenkins > Nodes > jenkins-frontend-inbound-agent > Create
Fill:
- Name: jenkins-frontend-inbound-agent  
- Remote root directory: /home/jenkins  
- Labels: jenkins-frontend-inbound-agent-label  
- Launch method: Launch agent by connecting it to the controller  
Take the secret: secret - (385166e968cf79801280b48b7352753180c8ccbab3f722e4f1ea65ee59d396cd) 

#### Update | Create jenkins-frontend-secret

kubectl apply -f kubernetes/secrets/jenkins-frontend-secret.yaml -n jenkins-ns
kubectl apply -f kubernetes/jenkins/jenkins-slave -n jenkins-ns

kubectl -n jenkins-ns get all,secrets,svc,configmap

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
github > (Reposirory) > settings > webhooks > Add webhook  
```
Fill:  
- Payload URL: <url from ngrok Forwarding> https://lightless-rocco-climacterically.ngrok-free.dev <and> /generic-webhook-trigger/ <and> /invoke?token=build-token
- Content type: application/json
- Let me select individual events: Pushes
- [v] Active  

```
#### Generic Webhook Trigger Plugin:
Manage Jenkins → Plugins → Generic Webhook Trigger

### CI Pipeline that builds and pushes a Docker image to Nexus
Trigger: PUSH → DEV branch  
#### Configure the Job in Jenkins
build_and_push_pipeline to catch webhook only 
```
Dashboard -> ci_pipeline -> Configure
Triggers:
[ ] - clean - not selected nothing
Pipeline -> Definition -> Pipeline script from SCM
Fill:
- SCM -> Git
- Repository URL -> https://github.com/evgeny-kor-m/final-infra-repo.git  
- Credentials -> select (github-infra-cred)    
- Branch -> */main
- Script Path -> pipelines/build.Jenkinsfile
```
#### Build.Jenkinsfile 
```
# All changes in triggers {} need Run the Job manually once to re-read the Jenkinsfile
pipeline {
    agent { label 'jenkins-frontend-inbound-agent-label' }
    
    triggers {
        GenericTrigger(
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

Jenkins API:
bash# Run the Job via the API
curl -X POST "http://localhost:30003/job/ci_pipeline/build" \
--user admin:<api-token>
```



#### Test PUSH 
curl -X POST "https://lightless-rocco-climacterically.ngrok-free.dev/generic-webhook-trigger/invoke?token=build-token" \
  -H "Content-Type: application/json" \
  -d '{"repository":{"name":"final-frontend-repo","clone_url":"https://github.com/evgeny-kor-m/final-frontend-repo.git"},"ref":"refs/heads/DEV","head_commit":{"id":"abc123","message":"test"}}'