kind delete cluster --name kind-01                                                              : delete cluster  
kind create cluster --name kind-01 --config ./kubernetes/kind-cluster/kind-config.yaml          : create cluster  
kind get clusters  


# Check that it loaded
docker exec -it kind-01-worker crictl images | grep backend  
docker exec -it kind-01-worker2 crictl images | grep backend  
docker exec -it kind-01-control-plane crictl images | grep backend  


#### Problem: containerd Cannot Resolve Kubernetes Internal DNS
Root Cause
In a kind cluster, each node runs as a Docker container. containerd (the container runtime) runs at the node level, outside the Kubernetes cluster network. This means containerd uses the node's system DNS (/etc/resolv.conf), not CoreDNS which is only available inside the cluster.

┌────────────────────────────────────────────────────────────────────────────────┐
│  WSL                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  kind Cluster                                                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │   │
│  │  │  kind-worker (Docker container = k8s Node)                       │   │   │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │   │   │
│  │  │  │  containerd (runs at NODE level)                           │  │   │   │
│  │  │  │                                                            │  │   │   │
│  │  │  │  pulling image:                                            │  │   │   │
│  │  │  │  nexus-service.nexus-ns.svc.cluster.local                  │  │   │   │
│  │  │  │         │ reads /etc/resolv.conf                           │  │   │   │
│  │  │  │         ▼                                                  │  │   │   │
│  │  │  │  nameserver 192.168.65.254                                 │  │   │   │
│  │  │  │  (Docker Desktop DNS) ← knows nothing about k8s services!  │  │   │   │
│  │  │  │         ▼                                                  │  │   │   │
│  │  │  │  192.168.65.254                                            │  │   │   │
│  │  │  │  "nexus-service...? ❌ no such host!"                     │  │   │   │
│  │  │  └────────────────────────────────────────────────────────────┘  │   │   │
│  │  │                                                                  │   │   │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │   │   │
│  │  │  │  Kubernetes Network                                        │  │   │   │
│  │  │  │  (invisible to containerd!)                                │  │   │   │
│  │  │  │                                                            │  │   │   │
│  │  │  │  CoreDNS pod                                               │  │   │   │
│  │  │  │  IP: 10.96.0.10                                            │  │   │   │
│  │  │  │  knows nexus-service... ✅                                │  │   │   │
│  │  │  │  BUT containerd never asks it! ❌                         │  │   │   │
│  │  │  │                                                            │  │   │   │
│  │  │  │  nexus-0 pod :8083 ✅                                     │  │   │   │
│  │  │  └────────────────────────────────────────────────────────────┘  │   │   │
│  │  └──────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────┘

RESULT: ImagePullBackOff ❌
"dial tcp: lookup nexus-service.nexus-ns.svc.cluster.local: no such host"

WHY:
  containerd  → uses NODE system DNS  → 192.168.65.254 ❌ (no k8s knowledge)
  k8s Pod     → uses CoreDNS          → 10.96.0.10     ✅ (knows everything)
  These are TWO DIFFERENT DNS servers!

Solution: Patch resolv.conf on Worker Nodes After Cluster Creation
After the cluster is created and CoreDNS is running, we copy a custom resolv.conf file to every node using docker cp. This replaces the default Docker Desktop DNS (192.168.65.254) with CoreDNS (10.96.0.10) as the primary nameserver, allowing containerd to resolve Kubernetes internal service names like nexus-service.nexus-ns.svc.cluster.local.
The file kubernetes/kind-cluster/resolv.conf is copied to /etc/resolv.conf on each node, then containerd is restarted to pick up the new DNS configuration.
Why after cluster creation?

During bootstrap, worker nodes need to resolve kind-01-control-plane to join the cluster. At that point CoreDNS is not yet running, so we must use the default DNS. Only after the cluster is fully up and CoreDNS is ready can we safely patch the nodes.

deploy.sh