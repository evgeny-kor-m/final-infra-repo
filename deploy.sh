#!/bin/bash

# 1. namespaces first
kubectl apply -f kubernetes/namespaces/

# 2. secrets
kubectl apply -k kubernetes/secrets/

# 3. mongodb
kubectl apply -k kubernetes/mongodb/

# wait for all mongodb pods to be Ready
kubectl wait --for=condition=Ready pod/mongodb-0 -n database --timeout=300s
kubectl wait --for=condition=Ready pod/mongodb-1 -n database --timeout=300s
kubectl wait --for=condition=Ready pod/mongodb-2 -n database --timeout=300s

# initialize Replica Set
kubectl cp kubernetes/mongodb/init-scripts/rs-initiate.js \
  database/mongodb-0:/tmp/rs-initiate.js
kubectl exec mongodb-0 -n database -- mongosh /tmp/rs-initiate.js || true

# wait for PRIMARY election
sleep 15

# create admin user (no credentials needed - localhost exception)
kubectl cp kubernetes/mongodb/init-scripts/create-admin.js \
  database/mongodb-0:/tmp/create-admin.js
kubectl exec mongodb-0 -n database -- mongosh /tmp/create-admin.js || true

# create other users with admin credentials
kubectl cp kubernetes/mongodb/init-scripts/create-other-users.js \
  database/mongodb-0:/tmp/create-other-users.js
kubectl exec mongodb-0 -n database -- mongosh \
  -u admin -p passw --authenticationDatabase admin  /tmp/create-other-users.js || true

# create tables
kubectl cp kubernetes/mongodb/init-scripts/create-tables.js \
  database/mongodb-0:/tmp/create-tables.js
kubectl exec mongodb-0 -n database -- mongosh \
  -u admin -p passw --authenticationDatabase admin  /tmp/create-tables.js || true

# create data
kubectl cp kubernetes/mongodb/init-scripts/create-data.js \
  database/mongodb-0:/tmp/create-data.js
kubectl exec mongodb-0 -n database -- mongosh \
  -u admin -p passw --authenticationDatabase admin  /tmp/create-data.js

# 4. mongo-express
kubectl apply -f kubernetes/mongo-express/ -n database
#kubectl -n database port-forward svc/mongo-express-service 8081:8081

# 5. nexus
kubectl apply -f kubernetes/nexus/ -n nexus-ns
kubectl wait --for=condition=Ready pod/nexus-0 -n nexus-ns --timeout=300s
kubectl port-forward svc/nexus-service 8082:8081 8083:8083 -n nexus-ns --address=0.0.0.0 &

### ---------------------------------------manually---------------------------------------

# Получи пароль
kubectl exec -it nexus-0 -n nexus-ns -- sh -c "cat /nexus-data/admin.password" ; echo

# Смени через API
curl -X PUT \
  "http://localhost:8082/service/rest/v1/security/users/admin/change-password" \
  -H "Content-Type: text/plain" \
  -u admin:00bb4c5e-1afb-4bde-ab3c-45ba6d276230 \
  -d "nexusadmin"

docker login 172.26.13.131:8083 -u admin -p nexusadmin
docker tag backend-image:latest 172.26.13.131:8083/backend-image:latest
docker push 172.26.13.131:8083/backend-image:latest

# 5. backend
kubectl apply -k kubernetes/backend/ -n backend
kubectl wait --for=condition=Ready pod/backend-app -n backend --timeout=300s
kubectl port-forward service/backend-service 5000:5000 -n backend &

# ps aux | grep port-forward
# 6. frontend
# kubectl apply -f kubernetes/frontend/ -n frontend