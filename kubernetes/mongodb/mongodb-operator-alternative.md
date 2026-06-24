# MongoDB Operator — Alternative Approach (Most Correct for Production)

## Why Operator?

|                | Manual (current)                     | MongoDB Operator          |  
|----------------|--------------------------------------|---------------------------|  
| Files          | StatefulSet + 2 Services + deploy.sh | MongoDBCommunity + Secret |  
| keyFile        | generate manually                    | automatic                 |  
| rs.initiate()  | deploy.sh                            | automatic                 |  
| Auth           | manual createUser                    | automatic                 |  
| Rolling update | manual                               | automatic                 |  
| Failover       | K8s basic                            | Operator managed          |  

---

## What the Operator Does Automatically

```
replicas: 3       →  creates 3 pods
type: ReplicaSet  →  rs.initiate() automatically
auth: SCRAM       →  creates keyFile, configures --auth
version: "8.0.0"  →  rolling update without downtime
```

---

## Step 1 — Install the Operator

```bash
helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo update

helm install community-operator mongodb/community-operator \
  --namespace mongodb-operator \
  --create-namespace

# verify
kubectl get pods -n mongodb-operator
```

---

## Step 2 — Create a Secret with Password

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: database
type: Opaque
stringData:
  password: passw
```

> Note: With Operator, one password is used for all users defined in the manifest.
> Each user can reference a different secret if needed.

---

## Step 3 — Create MongoDBCommunity Manifest

```yaml
# mongodb-community.yaml
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb
  namespace: database
spec:
  members: 3                    # 3-node Replica Set
  type: ReplicaSet
  version: "8.0.0"
  security:
    authentication:
      modes: ["SCRAM"]          # username/password authentication
  users:
  - name: admin
    db: admin
    passwordSecretRef:
      name: mongodb-secret      # takes password from Secret
    roles:
    - name: root
      db: admin
  - name: backend_user
    db: admin
    passwordSecretRef:
      name: mongodb-secret
    roles:
    - name: readWrite
      db: hoteldb
  - name: readonly_user
    db: admin
    passwordSecretRef:
      name: mongodb-secret
    roles:
    - name: read
      db: hoteldb
  additionalMongodConfig:
    storage.wiredTiger.engineConfig.journalCompressor: zlib
  statefulSet:
    spec:
      volumeClaimTemplates:
      - metadata:
          name: data-volume
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 500Mi
```

---

## Step 4 — Deploy

```bash
kubectl apply -f kubernetes/mongodb/secret.yaml -n database
kubectl apply -f kubernetes/mongodb/mongodb-community.yaml

# watch pods come up
kubectl get pods -n database -w
```

---

## What the Operator Does Automatically

```
kubectl apply -f mongodb-community.yaml
        ↓
Operator creates StatefulSet
        ↓
Operator creates keyFile Secret
        ↓
Operator runs rs.initiate()
        ↓
Operator creates users (admin, backend_user, readonly_user)
        ↓
MongoDB works with --auth ✅
```

---

## Project Structure with Operator

```
kubernetes/mongodb/
├── mongodb-community.yaml    ← replaces StatefulSet + Services + deploy.sh init logic
├── job-init-data.yaml        ← still needed for collections and initial data
└── secret.yaml
```

### job-init-data.yaml — still needed for data

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-init-data
  namespace: database
spec:
  template:
    spec:
      containers:
      - name: init-data
        image: mongo:latest
        command:
        - mongosh
        - mongodb://backend_user:passw@mongodb-svc.database.svc.cluster.local/hoteldb?authSource=admin
        - --eval
        - |
          db.createCollection('hotels');
          db.createCollection('reservations');
          db.hotels.createIndex({ hotel_id: 1 }, { unique: true });
          db.reservations.createIndex({ reservation_id: 1 }, { unique: true });
          db.hotels.insertMany([
            { hotel_id: '1', hotel_name: 'Hilton', description: 'Hilton the best', location: 'Tel Aviv', price_per_night: '700' },
            { hotel_id: '2', hotel_name: 'Leonardo', description: 'Leonardo the best', location: 'Dead Sea', price_per_night: '800' },
            { hotel_id: '3', hotel_name: 'Caesar Premier Eilat', description: 'Caesar Premier Eilat the best', location: 'Eilat', price_per_night: '900' }
          ]);
          print('Data initialized successfully!');
      restartPolicy: OnFailure
```

---

## Connection String with Operator

The Operator creates its own Service named `mongodb-svc`:

```
mongodb://backend_user:passw@mongodb-svc.database.svc.cluster.local/hoteldb?replicaSet=rs0&authSource=admin&readPreference=secondaryPreferred
```

---

## Note on Current Approach

The current manual approach (StatefulSet + deploy.sh) works correctly and demonstrates understanding of how MongoDB Replica Sets work internally. The Operator approach is recommended for production as it handles all the complexity automatically.
