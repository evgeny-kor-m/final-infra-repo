# Cluster Resource Plan | 6GB / 4 cores WSL2

### WSL2 Configuration:
[wsl2]
kernelCommandLine = systemd.unified_cgroup_hierarchy=1
memory=6GB
processors=4
swap=2GB

### Scenarios By namespaces
Scenario A — CI/CD mode: Jenkins + Nexus + ArgoCD + Apps + Database (ELK off)
Scenario B — Monitoring mode: ELK + Apps + Database (Jenkins/Nexus/ArgoCD scaled to 0)
Scenario C — Always running: frontend, backend, database, kube-system

Full table:
| Namespace  | Scenario | req.mem | lim.mem | req.cpu | lim.cpu | Main pods
|---------------------------------------------------------------------------------------------------------------------|
| jenkins-ns |     A    | 1400Mi  | 2.4Gi   | 700m    | 1500m   | jenkins-0, ci-agent (temp)                          |
| nexus-ns   |     A    | 1200Mi  | 1.8Gi   | 400m    | 1000m   | nexus-0                                             |
| argocd     |     A    | 900Mi   | 1.4Gi   | 700m    | 1500m   | 7 components ArgoCD                                 |
| frontend   |     C    | 400Mi   | 500Mi   | 250m    | 500m    | frontend-app ×1                                     |
| backend    |     C    | 600Mi   | 750Mi   | 350m    | 750m    | backend-app ×1                                      |
| database   |     C    | 700Mi   | 2.8Gi   | 200m    | 500m    | mongodb-0 (1 replica), mongo-express                |
| monitoring |     B    | 2.5Gi   | 4.5Gi   | 1200m   | 3500m   | ES, Kibana, Logstash, Filebeat×2, Metricbeat×2, APM |
| kube-system|     C    | 400Mi   | 600Mi   | 300m    | 500m    | etcd, coredns, kubelet, kindnet                     |

                          | Scenario A (CI/CD) + C | Scenario B (Monitoring) + C | Scenario A+B+C (all at once)
|-------------------------------------------------------------------------------------------------------------
| requests.memory         | 5.47Gi                 | 4.55Gi                      | 7.97Gi 
| 6Gi spare               | 0.53Gi [!]             | 2.25Gi [v]                  | -1.97Gi  [x]
| limits.memory           | 10.42Gi                | 9.32Gi                      | 14.92Gi 
| Over-commit             | × 1.7                  | ×1.6                        | ×2.5 
| Is 6GB really possible? | [!] tight              | [v] yes                     | [x] impossible

---

# How to measure 

# --- NODES ---

# Real memory usage per node (via cgroups, no metrics-server needed)
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $node ==="
  docker exec $node cat /sys/fs/cgroup/memory.current 2>/dev/null || \
  docker exec $node cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null
done

# Node capacity and allocated requests/limits
kubectl describe nodes | grep -E "^Name:|Allocated" -A6

# Node status overview
kubectl get nodes -o wide

# --- PODS ---

# All running pods with node placement
kubectl get pods -A -o wide

# Only running pods
kubectl get pods -A --field-selector=status.phase=Running

# Pods NOT running (errors, pending, crashloop)
kubectl get pods -A | grep -v Running | grep -v Completed

# Pods sorted by namespace
kubectl get pods -A --sort-by='.metadata.namespace'

# --- QUOTAS ---

# All ResourceQuotas across namespaces (used vs limit)
kubectl get resourcequota -A

# Detailed quota per namespace
kubectl describe resourcequota -A

# LimitRanges (default limits per container)
kubectl get limitrange -A

# --- SPECIFIC NAMESPACE ---

# Full status of a namespace
kubectl -n monitoring get all,secrets,svc,configmap

# Events in a namespace (errors, warnings)
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -20

# --- DNS CHECK ---

# Test DNS resolution from jenkins namespace
kubectl run test-dns --rm -it --image=busybox -n jenkins-ns \
  --restart=Never -- nslookup nexus-service.nexus-ns.svc.cluster.local

---

## jenkins-ns [Scenario A]
**ResourceQuota:** req.mem=1400Mi | lim.mem=2.4Gi | req.cpu=700m | lim.cpu=1500m

| Pod                  | req.mem    | lim.mem    | req.cpu  | lim.cpu   | Note                                |
|----------------------|------------|------------|----------|-----------|-------------------------------------|
| jenkins-0            | 400Mi      | 700Mi      | 200m     | 500m      | JVM -Xms256m -Xmx512m               | 
| ci-agent (ephemeral) | 768Mi      | 1536Mi     | 300m     | 1000m     | Created per pipeline run, npm build |
| **PODS SUM**         | **1168Mi** | **2236Mi** | **500m** | **1500m** |                                     |

---

## nexus-ns [Scenario A]
**ResourceQuota:** req.mem=1200Mi | lim.mem=1.8Gi | req.cpu=400m | lim.cpu=1000m

| Pod | req.mem | lim.mem | req.cpu | lim.cpu | Note |
|-----|---------|---------|---------|---------|------|
| nexus-0 | 1000Mi | 1500Mi | 200m | 300m | JVM, Docker registry |
| **PODS SUM** | **1000Mi** | **1500Mi** | **200m** | **300m** | |

---

## argocd [Scenario A]
**ResourceQuota:** req.mem=900Mi | lim.mem=1.4Gi | req.cpu=700m | lim.cpu=1500m

| Pod | req.mem | lim.mem | req.cpu | lim.cpu |
|-----|---------|---------|---------|---------|
| argocd-server | 100Mi | 200Mi | 60m | 150m |
| argocd-repo-server | 100Mi | 200Mi | 60m | 150m |
| argocd-application-controller | 100Mi | 200Mi | 60m | 150m |
| argocd-dex-server | 100Mi | 200Mi | 60m | 150m |
| argocd-redis | 100Mi | 200Mi | 60m | 150m |
| argocd-applicationset-controller | 100Mi | 200Mi | 60m | 150m |
| argocd-notifications-controller | 100Mi | 200Mi | 60m | 150m |
| **PODS SUM** | **700Mi** | **1400Mi** | **420m** | **1050m** | |

---

## frontend [Scenario C]
**ResourceQuota:** req.mem=400Mi | lim.mem=500Mi | req.cpu=250m | lim.cpu=500m

| Pod | req.mem | lim.mem | req.cpu | lim.cpu | Note |
|-----|---------|---------|---------|---------|------|
| frontend-app (×5 replicas) | 80Mi | 100Mi | 50m | 100m | per pod |
| **PODS SUM ×5** | **400Mi** | **500Mi** | **250m** | **500m** | |

---

## backend [Scenario C]
**ResourceQuota:** req.mem=600Mi | lim.mem=750Mi | req.cpu=350m | lim.cpu=750m

| Pod | req.mem | lim.mem | req.cpu | lim.cpu | Note |
|-----|---------|---------|---------|---------|------|
| backend-app (×5 replicas) | 120Mi | 150Mi | 70m | 150m | per pod |
| **PODS SUM ×5** | **600Mi** | **750Mi** | **350m** | **750m** | |

---

## database [Scenario C]
**ResourceQuota:** req.mem=700Mi (dev) / 1.6Gi (demo 3 replicas) | lim.mem=2.8Gi | req.cpu=200m | lim.cpu=500m

| Pod | req.mem | lim.mem | req.cpu | lim.cpu | Note |
|-----|---------|---------|---------|---------|------|
| mongodb-0 | 350Mi | 700Mi | 100m | 300m | 1 replica dev / 3 replicas demo |
| mongo-express | 128Mi | 256Mi | 50m | 150m | |
| **PODS SUM (dev)** | **478Mi** | **956Mi** | **150m** | **450m** | |

---

## monitoring [Scenario B]
**ResourceQuota:** req.mem=2.5Gi | lim.mem=4.5Gi | req.cpu=1200m | lim.cpu=3500m

| Pod                     | req.mem    | lim.mem    | req.cpu   | lim.cpu   | Note                      |
|-------------------------|------------|------------|-----------|-----------|---------------------------|
| elasticsearch-master-0  | 512Mi      | 1024Mi     | 200m      | 1000m     | JVM -Xmx512m, StatefulSet |
| kibana-kibana           | 512Mi      | 1024Mi     | 200m      | 500m      | Deployment                |
| logstash-logstash-0     | 512Mi      | 768Mi      | 100m      | 500m      | JVM -Xmx512m, StatefulSet |
| filebeat (×2 workers)   | 100Mi      | 200Mi      | 100m      | 200m      | DaemonSet                 |
| metricbeat (×2 workers) | 100Mi      | 200Mi      | 100m      | 200m      | DaemonSet                 |
| metricbeat-metrics      | 130Mi      | 250Mi      | 100m      | 200m      | Deployment                |
| metricbeat-kube-state   | 130Mi      | 250Mi      | 100m      | 200m      | Deployment                |
| apm-server              | 100Mi      | 256Mi      | 100m      | 200m      | Deployment                |
| **PODS SUM**            | **2196Mi** | **3972Mi** | **1000m** | **3000m** | 

---

## kube-system [Scenario C] (no ResourceQuota)

| Pod | req.mem | lim.mem | req.cpu | lim.cpu |
|-----|---------|---------|---------|---------|
| etcd | 100Mi | 200Mi | 100m | 200m |
| kube-apiserver | 100Mi | 200Mi | 100m | 200m |
| kube-scheduler | 50Mi | 100Mi | 50m | 100m |
| kube-controller-manager | 50Mi | 100Mi | 50m | 100m |
| coredns ×2 | 70Mi | 170Mi | 100m | 200m |
| kindnet ×3 | 30Mi | 50Mi | 100m | 200m |
| **PODS SUM** | **400Mi** | **820Mi** | **600m** | **1000m** | |

---

## Summary

| | Scenario A + C | Scenario B + C | Scenario A+B+C |
|--|--|--|--|
| **requests.memory** | **5.47Gi** | **3.75Gi** | **7.17Gi** |
| **Available from 6Gi** | **0.53Gi ⚠️** | **2.25Gi ✅** | **-1.17Gi ❌** |
| **limits.memory** | 10.42Gi | 7.12Gi | 12.72Gi |
| **Over-commit** | ×1.7 | ×1.2 | ×2.1 |
| **Feasible on 6GB?** | ⚠️ tight | ✅ yes | ❌ impossible |

