# final-infra-repo

<p align="left">
  <img src="docs/schema.jpg" width="1100" alt="view"/>
</p>

### Project include 
backend repo:   https://github.com/evgeny-kor-m/final-backend-repo  
frontend repo:  https://github.com/evgeny-kor-m/final-frontend-repo  

### Sync .wslconfig with Docker Desktop to limit resources
```
[wsl2]
kernelCommandLine = systemd.unified_cgroup_hierarchy=1
memory=8GB
processors=8
swap=2GB
```

#### Aliases
```
source alias.txt
```

#### Deployment
```
# Run ./deploy.sh to deploy following parts automaticaly:
Namespaces
LimitRange & ResourceQuota
Secrets
Mongodb 3 replicas and initially data
Mongo-express
Nexus

# To deploy the following components, follow the instructions in their README.md files.
Nexus init configuration include push first application images
Jenkins and configurations
ArgoCD

# To deploy backend:
kubectl apply -k kubernetes/backend/ -n backend
kubectl wait --for=condition=Ready pod/backend-app -n backend --timeout=300s

# To deploy frontend
kubectl apply -f kubernetes/frontend/ -n frontend

## 
# To deploy ELK follow the instructions in Monitoring README.md file
```

#### Switch betwin scenarios
```
To scale-down EFLK and scale-up ArgoCD Jenkins Nexus and use DEV scenario run:
./kubernetes/Scenario-A-dev-ci-cd.sh

To scale-down ArgoCD Jenkins Nexus and scale-up EFLK and use Monitoring scenario run:
./kubernetes/Scenario-B-monitoring.sh

```

#### Temporary Solution. Copy image into cluster manually
Upload the image to the kind cluster:
```
#1. Remove the old one from kind
docker exec -it kind-01-worker crictl rmi backend-image:latest
docker exec -it kind-01-worker2 crictl rmi backend-image:latest
docker exec -it kind-01-control-plane crictl rmi backend-image:latest

# Upload the local image to kind
kind load docker-image backend-image:latest --name kind-01

# Check that it loaded
docker exec -it kind-01-worker crictl images | grep backend
docker exec -it kind-01-worker2 crictl images | grep backend
docker exec -it kind-01-control-plane crictl images | grep backend
```







