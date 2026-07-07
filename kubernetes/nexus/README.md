
#### Issue with pushing the images.
```
Problem with defferent network  
┌──────────────────────────────────────────────────────────┐
│  Laptop (Windows)                                        │
│                                                          │
│  Docker Desktop Settings → Docker Engine                 │
│  {                                                       │
│    "insecure-registries": ["172.26.13.131:8083"]         │
│  }                                                       │
│                                                          │
│  docker push 172.26.13.131:8083/backend-image:latest     │
│         │                                                │
│         │ via IP WSL                                     │
│  ┌──────▼────────────────────────────────────────────┐   │
│  │  Docker Desktop VM                                │   │
│  │         │                                         │   │
│  │  ┌──────▼─────────────────────────────────────┐   │   │
│  │  │  WSL (172.26.13.131)                       │   │   │
│  │  │                                            │   │   │
│  │  │  kubectl port-forward svc/nexus-service    │   │   │
│  │  │  8083:8083 -n nexus-ns --address=0.0.0.0   │   │   │
│  │  │         │                                  │   │   │
│  │  │  ┌──────▼───────────────────────────────┐  │   │   │
│  │  │  │  kind cluster                        │  │   │   │
│  │  │  │  ┌───────────────────────────────┐   │  │   │   │
│  │  │  │  │  nexus-0 pod :8083            │   │  │   │   │
│  │  │  │  │  image saved in PVC           │   │  │   │   │
│  │  │  │  └───────────────────────────────┘   │  │   │   │
│  │  │  └──────────────────────────────────────┘  │   │   │
│  │  └────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```
#### Prerequisite for pushing image from Docker Desktop (locally) -> port-forward + insecure-registry с IP WSL
```
# Find out the WSL IP
hostname -I | awk '{print $1}'

# Login via IP
docker login 172.26.13.131:8083 -u admin -p nexusadmin

# Docker Desktop -> Settings -> Docker Engine
{
  "insecure-registries": [ "172.26.13.131:8083" ]
}
Save & Apply

# Whitch port-forward run
ps aux | grep port-forward

```
#### Create
```
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/nexus/
kubectl wait --for=condition=Ready pod -n nexus-ns --all --timeout=60s

kubectl rollout restart statefulset/nexus -n nexus-ns
# Check ... on start ....
kubectl logs nexus-0 -n nexus-ns -f

# Check password for user admin:
kubectl exec nexus-0 -n nexus-ns -- cat /nexus-data/admin.password ; echo

http://127.0.0.1:30005

# Change password 
admin/nexusadmin

[v] Enable anonymous access
Settings -> Repository -> Create Repository docker(hosted) Name: backend-image / docker-hosted
[v] Other Connectors
  [v] HTTP 8083
[v] Allow anonymous Docker pulls
Deployment policy : Allow redeploy

Settings -> Security -> Realms
Docker Bearer Token Realm -> move to -> Active
Save

kubectl port-forward svc/nexus-service 8083:8083 -n nexus-ns  --address=0.0.0.0 &

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag backend-image:latest 172.26.13.131:8083/backend-image:latest
docker push 172.26.13.131:8083/backend-image:latest
docker tag frontend-image:latest 172.26.13.131:8083/frontend-image:latest
docker push 172.26.13.131:8083/frontend-image:latest
```

## Image Scanning and Vulnerability Analysis

Trivy remains the right choice because:

It doesn't require a database or server—it's just a binary in the agent pod (critical with 6GB of RAM).
--exit-code 1 provides the desired "fail pipeline" behavior out of the box without any additional logic.
The only free tool that scans both OS layers and application dependencies equally well (Flask backend + React frontend).

https://oneuptime.com/blog/post/2026-02-02-trivy-container-scanning/view  
https://oneuptime.com/blog/post/2026-01-27-trivy-kubernetes-security/view#installing-the-trivy-operator

kubectl apply -f ./kubernetes/nexus/ -n nexus-ns
kubectl rollout restart deployment/trivy-server -n nexus-ns