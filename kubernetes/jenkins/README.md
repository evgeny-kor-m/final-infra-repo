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
  kubectl apply -f kubernetes/jenkins/ -n jenkins-ns

  kubectl exec jenkins-97f9bfbdb-ptbrx  -n jenkins-ns -- cat /var/jenkins_home/secrets/initialAdminPassword
  38f28921d6ea4fd9bbb5333262f59d8e

http://localhost:30003

admin/admin

### Access to GitHub Repo
PAT on GitHub / Frontend / Backend for CI
Repositories:
├── Metadata    -> Read-only
├── Contents    -> Read-only
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
- ID: github-credentials
Save
```
Dashboard -> ci_frontend_pipeline -> Configure
Triggers:
[v] GitHub hook trigger for GITScm polling
Pipeline -> Definition -> Pipeline script from SCM
Fill:
- SCM -> Git
- Repository URL -> https://github.com/evgeny-kor-m/final-frontend-repo.git  
- Credentials → select github-frontend-cred
- Branch → */DEV
- Script Path → pipelines/build.Jenkinsfile
