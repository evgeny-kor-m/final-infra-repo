
### Prerequisite for pushing image from Docker Desktop (locally) -> port-forward + insecure-registry с IP WSL

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

kubectl port-forward svc/nexus-service 8083:8083 -n nexus-ns --address=0.0.0.0 &

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag backend-image:latest 172.26.13.131:8083/backend-image:latest
docker push 172.26.13.131:8083/backend-image:latest

```