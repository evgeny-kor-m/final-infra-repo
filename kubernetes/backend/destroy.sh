#!/bin/bash
# cleanup.sh — backend clean

kubectl -n backend delete configmap backend-cm
kubectl -n backend delete deploy backend-app
kubectl -n backend delete svc backend-service
kubectl -n backend delete secrets backend-service
kubectl -n backend get all,secrets,svc,configmap