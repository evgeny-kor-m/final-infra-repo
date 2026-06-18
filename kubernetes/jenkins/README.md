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



