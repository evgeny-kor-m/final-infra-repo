#!/bin/bash
set -e    # ← остановить скрипт при любой ошибке

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

# create users
kubectl cp kubernetes/mongodb/init-scripts/create-users.js \
  database/mongodb-0:/tmp/create-users.js
kubectl exec mongodb-0 -n database -- mongosh /tmp/create-users.js || true

# create data
kubectl cp kubernetes/mongodb/init-scripts/create-data.js \
  database/mongodb-0:/tmp/create-data.js
kubectl exec mongodb-0 -n database -- mongosh \
  -u admin -p passw --authenticationDatabase admin  /tmp/create-data.js

# 4. mongo-express
kubectl apply -f kubernetes/mongo-express/ -n database

# 5. backend
# kubectl apply -f kubernetes/backend/ -n frontend

# 6. frontend
# kubectl apply -f kubernetes/frontend/ -n frontend