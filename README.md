# final-infra-repo

source alias.txt

## Database

<p align="left">
  <img src="kubernetes/pic/mongodb_replicaset.jpg" width="500" alt="view"/>
</p>
<p align="rigth">
  <img src="kubernetes/pic/3replicas.jpg" width="500" alt="view"/>
</p>

For production, MongoDB Operator or Bitnami Helm would be used.  

#### Clean all
```
kubectl delete statefulset mongodb -n database
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
kubectl exec -it mongodb-0 -n database -- mongosh -u admin -p passw  --eval "db.version()"
```
#### Set Up 3 Replicas
To deploy a 3-replica MongoDB Replica Set in Kubernetes, use a StatefulSet along with a Headless Service to provide each database pod with a stable, predictable network identity
- Headless Service - When combined with StatefulSets, they can give you unique DNS addresses that let you directly access the pods! This is perfect for creating MongoDB replica sets, because our app needs to connect to all of the MongoDB nodes individually.   



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

# Connect to primary and initialize replica set
kubectl exec -it mongodb-0 -n mongodb -- mongosh

# In mongosh shell:
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb-headless.mongodb.svc.cluster.local:27017", priority: 2 },
    { _id: 1, host: "mongodb-1.mongodb-headless.mongodb.svc.cluster.local:27017", priority: 1 },
    { _id: 2, host: "mongodb-2.mongodb-headless.mongodb.svc.cluster.local:27017", priority: 1 }
  ]
})

# Verify replica set status
rs.status()
```
Example :  https://oneuptime.com/blog/post/2026-01-25-mongodb-replica-sets-kubernetes/view   

#### Craete Mongo Express viewer
```
kubectl apply -f kubernetes/mongo-express -n database
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
