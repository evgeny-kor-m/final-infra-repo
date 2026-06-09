# final-infra-repo

source alias.txt

## Database
For production, MongoDB Operator or Bitnami Helm would be used.  
<p align="left">
  <img src="pic/mongodb_replicaset.jpg" width="600" alt="view"/>
</p>
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

https://oneuptime.com/blog/post/2026-01-25-mongodb-replica-sets-kubernetes/view

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
```

#### Craete Mongo Express viewer
```
kubectl apply -f kubernetes/mongo-express -n database
kubectl -n database port-forward svc/mongo-express-service 8081:8081
```
#### (Optionaly) Manually add row into table
```
kubectl exec -it mongodb-0 -n database -- mongosh
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
