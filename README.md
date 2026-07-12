# final-infra-repo

<p align="left">
  <img src="docs/schema.jpg" width="500" alt="view"/>
</p>

### Sync .wslconfig with Docker Desktop to limit resources
[wsl2]
kernelCommandLine = systemd.unified_cgroup_hierarchy=1
memory=8GB
processors=8
swap=2GB

Namespacerequests.memrequests.cpulimits.memlimits.cpujenkins-ns1Gi1.01.3Gi1.5argocd700Mi0.51Gi1.0nexus-ns600Mi0.4900Mi0.8monitoring2Gi1.02.8Gi2.0frontend200Mi0.2350Mi0.4backend200Mi0.2350Mi0.4database300Mi0.2500Mi0.4Сумма requests~5Gi~3.5 coresСумма limits~7.2Gi~6.5 cores

## Database MongoDB

For production, MongoDB Operator or Bitnami Helm would be used.  
### Scop
```
1. kubectl apply -k kubernetes/mongodb/
2. StatefulSet creates 3 pods
3. deploy.sh waits for all pods to be Ready
4. rs.initiate() via kubectl exec (localhost exception)
5. sleep 15 (waiting for PRIMARY)
6. createUser: admin (without credentials)
7. createUser: backend_user, readonly_user (with credentials)
8. createCollection + createIndex + insertMany
9. keyFile created manually via openssl → added to Secret
10. MongoDB works with --auth
```
#### Aliases
```
source alias.txt
```
#### Clean all
```
kubectl delete statefulset mongodb -n database
kubectl delete deploy mongo-express  -n database
kubectl get pods -n database -w
kubectl delete pvc --all -n database
kubectl delete namespace database
```
#### Create all resources
```
# Generate keyFile and add to Secret for authentication
openssl rand -base64 756 | tr -d '\n' > /tmp/keyfile
cat /tmp/keyfile | base64 | tr -d '\n'

kubectl apply -f kubernetes/namespace.yaml

# Run Kustomization yaml, he start all another resorces
kubectl apply -k kubernetes/mongodb/
kubectl get pods -n database -w
k get pvc
d get sts mongodb
kubectl exec -it mongodb-0 -n database -- mongosh -u admin -p passw --authenticationDatabase admin --eval "db.version()"
```
#### Encoding values in secrets
```
echo -n "backend_user" | base64
# → YmFja2VuZF91c2Vy

# Decoding 
echo "YmFja2VuZF91c2Vy" | base64 --decode
```

#### Set Up 3 Replicas
To deploy a 3-replica MongoDB Replica Set in Kubernetes, use a StatefulSet along with a Headless Service to provide each database pod with a stable, predictable network identity
- Headless Service - When combined with StatefulSets, they can give you unique DNS addresses that let you directly access the pods! This is perfect for creating MongoDB replica sets, because our app needs to connect to all of the MongoDB nodes individually.   

<p align="left">
  <img src="kubernetes/pic/mongodb_replicaset.jpg" width="500" alt="view"/>
  <img src="kubernetes/pic/3replicas.jpg" width="500" alt="view"/>
</p>

##### Manually
In the kubernetes/mongodb/statefulset.yaml
```
-------------
spec:
  replicas: 3                          # 3 pods for Replica Set
  serviceName: "mongodb-headless"      # must match Headless Service name
-------------
      containers:
        command:
        - mongod
        - "--replSet"                # enable Replica Set mode 
        - "rs0"                      # Sets the replica set name must match Job
        - "--bind_ip_all"            # accept connections from all IPs
        - "--auth"                   # enable authentication
------------
# Wait for all pods to be running
kubectl  get all,secrets,svc,pvc,rs,configmap -n database

kubectl get secret mongodb-secret -n database -o jsonpath='{.data.username}' | base64 -d
kubectl get secret mongodb-secret -n database -o jsonpath='{.data.password}' | base64 -d

# Connect to primary and initialize replica set
kubectl exec -it mongodb-0 -n database -- mongosh

# In mongosh shell:
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb-headless.database.svc.cluster.local:27017", priority: 2 },
    { _id: 1, host: "mongodb-1.mongodb-headless.database.svc.cluster.local:27017", priority: 1 },
    { _id: 2, host: "mongodb-2.mongodb-headless.database.svc.cluster.local:27017", priority: 1 }
  ]
})

# Verify replica set status
rs.status()
```
Example :  https://oneuptime.com/blog/post/2026-01-25-mongodb-replica-sets-kubernetes/view   

kubectl scale statefulset mongodb -n database --replicas=1

#### Craete Mongo Express viewer
```
kubectl apply -f kubernetes/mongo-express -n database
kubectl rollout restart deployment/mongo-express -n database
kubectl -n database port-forward svc/mongo-express-service 8081:8081
```
#### (Optionaly) Manually add row into table
```
kubectl exec -it mongodb-0 -n database -- mongosh -u admin -p passw
# show all databases
show dbs

# switch to the database
use reservations

# show collections
show collections

# find all documents
db.reservations.find()

# insert a document
db.reservations.insertOne({ reservation_id: "1", full_name: "John Smite",  email_address: "JohnSmite@domain.com",  checkIn_date: "02/06/2026", checkOut_date: "10/06/2026",  hotel_id: "1" });

# delete a document
db.reservations.deleteOne({ full_name: "John Smite" })

# exit
exit
```
#### Connection string for application
Must use all replicas in URL to allow MongoDB driver to route reads to Secondary and writes to Primary.
```
mongodb://backend_user:backend_pass@mongodb-service.database.svc.cluster.local:27017/hoteldb?replicaSet=rs0&readPreference=secondaryPreferred

| readPreference       | Behavior                            |
|------------------------------------------------------------|
| `primary`            | only (default)                      |
| `primaryPreferred`   | Primary, if unavailable - Secondary |
| `secondary`          | only                                |
| `secondaryPreferred` | Secondary, if unavailable - Primary |
| `nearest`            | Least Latency                       |

> Note: Writes always go to Primary regardless of readPreference.
```
For developing
```
kubectl port-forward service/mongodb-service 27017:27017 -n database
```

## Mongo-express

http://localhost:30001


## Backend 

kubectl create configmap backend-cm \
  --from-literal=DB_NAME=hoteldb \
  --from-literal=DB_HOST="mongodb-service.database.svc.cluster.local" \
  --from-literal=DB_PORT=27017 \
  --from-literal=DB_CONNECT_STR="?authSource=admin&replicaSet=rs0&readPreference=secondaryPreferred" \
  --dry-run=client -o yaml > 01-configmap.yaml

kubectl port-forward service/backend-service 5000:5000 -n backend &

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

kubectl port-forward service/backend-service 5000:5000 -n backend

## Nexus

### Prerequisite for pushing image from Docker Desktop (locally) -> port-forward + insecure-registry с IP WSL
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

```

```
kubectl apply -f kubernetes/namespaces/

kubectl apply -f kubernetes/nexus/

kubectl wait --for=condition=Ready pod -n nexus-ns --all --timeout=60s

# Check password for user admin:
kubectl exec nexus-0 -n nexus-ns -- cat /nexus-data/admin.password ; echo

kubectl port-forward pod/nexus-0 8083:8081 -n nexus-ns
http://127.0.0.1:8083

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

kubectl port-forward svc/nexus-service 8083:8083 -n nexus-ns --address=0.0.0.0

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag backend-image:latest 172.26.13.131:8083/backend-image:latest
docker push 172.26.13.131:8083/backend-image:latest


```
## Frontend 
```
kubectl create configmap backend-cm \
  --from-literal=BACKEND_URL="backend-service.backend.svc.cluster.local:5000" \
  --dry-run=client -o yaml > 01-configmap.yaml
# Run
  kubectl apply -f kubernetes/frontend/ -n frontend
  ```

## Jenkins
```
# Run
  kubectl apply -f kubernetes/jenkins/jenkins-master -n frontend
k get all,cm,secrets
```






