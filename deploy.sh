#!/bin/bash
source .env
source alias.txt

# 1. namespaces first
kubectl apply -f kubernetes/namespaces/
# LimitRange & ResourceQuota
kubectl apply -f kubernetes/limit-quotas/

# 2. secrets
kubectl apply -k kubernetes/secrets/

kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-service.nexus-ns.svc.cluster.local:8083 \
  --docker-username=${NEXUS_USER} \
  --docker-password=${NEXUS_PASSWORD} \
  -n backend

kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-service.nexus-ns.svc.cluster.local:8083 \
  --docker-username=${NEXUS_USER} \
  --docker-password=${NEXUS_PASSWORD} \
  -n frontend

kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus-service.nexus-ns.svc.cluster.local:8083 \
  --docker-username=${NEXUS_USER} \
  --docker-password=${NEXUS_PASSWORD} \
  -n jenkins-ns

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
# kubectl port-forward svc/nexus-service 8082:8081 8083:8083 -n nexus-ns --address=0.0.0.0 > /dev/null 2>&1 &

### ---------------------------------------manually---------------------------------------

# # Take password
# kubectl exec -it nexus-0 -n nexus-ns -- sh -c "cat /nexus-data/admin.password" ; echo
# Change password: admin/nexusadmin
# # Change via API
# curl -X PUT \
#   "http://localhost:8082/service/rest/v1/security/users/admin/change-password" \
#   -H "Content-Type: text/plain" \
#   -u admin:******************************* \
#   -d "nexusadmin"

# docker login 172.26.13.131:8083 -u admin -p nexusadmin
# docker tag backend-image:latest 172.26.13.131:8083/backend-image:latest
# docker push 172.26.13.131:8083/backend-image:latest
# docker tag frontend-image:latest 172.26.13.131:8083/frontend-image:latest
# docker push 172.26.13.131:8083/frontend-image:latest

# docker build --no-cache --provenance=false -t jenkins-inbound-agent-image:v7 -f ./kubernetes/jenkins/Dockerfile .

# # Push to Nexus
# kubectl port-forward svc/nexus-service 8082:8081 8083:8083 -n nexus-ns --address=0.0.0.0

# docker login 172.26.13.131:8083 -u admin -p nexusadmin
# docker tag jenkins-inbound-agent-image:v7  172.26.13.131:8083/jenkins-inbound-agent-image:v7
# docker push 172.26.13.131:8083/jenkins-inbound-agent-image:v7

# echo "=== 6. Jenkins (builds images, pushes to Nexus) ==="
# kubectl apply -f kubernetes/jenkins/
# kubectl wait --for=condition=Ready pod/jenkins-0 -n jenkins-ns --timeout=180s

# echo "=== 7. ArgoCD (deploys from Git, pulls images from Nexus) ==="
# kubectl apply -f kubernetes/secrets/infra-repo-secret.yaml
# kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.4/manifests/crds/applicationset-crd.yaml --server-side
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.4/manifests/install.yaml --server-side --force-conflicts
# kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30004, "protocol": "TCP", "name": "http"}]}}'
# kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s

# # 8. backend
# kubectl apply -k kubernetes/backend/ -n backend
# kubectl wait --for=condition=Ready pod/backend-app -n backend --timeout=300s
# kubectl port-forward service/backend-service 5000:5000 -n backend &

# # ps aux | grep port-forward
# # kill 43329  or ->
# # pkill -f "port-forward svc/nexus-service"

# # 9. frontend
# kubectl apply -f kubernetes/frontend/ -n frontend











