#!/bin/bash

# 1. namespaces first
kubectl apply -f kubernetes/namespaces/

# 2. secrets
kubectl apply -k kubernetes/secrets/

# 3. mongodb
kubectl apply -k kubernetes/mongodb/

# 4. mongo-express
kubectl apply -f kubernetes/mongo-express/ -n database

# 5. backend (когда будет готов)
# kubectl apply -f kubernetes/backend/ -n frontend

# 6. frontend (когда будет готов)
# kubectl apply -f kubernetes/frontend/ -n frontend