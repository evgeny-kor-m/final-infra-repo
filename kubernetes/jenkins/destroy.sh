#!/bin/bash

kubectl delete sts jenkins -n jenkins-ns
kubectl delete deploy jenkins-frontend-agent -n jenkins-ns

kubectl wait --for=delete pod --all -n jenkins-ns --timeout=60s

kubectl delete svc jenkins-service -n jenkins-ns
kubectl delete pvc --all -n jenkins-ns

kubectl wait --for=delete pvc --all -n jenkins-ns --timeout=60s
kubectl get pvc -n jenkins-ns --no-headers 2>/dev/null | grep -q . && echo "PVC exists!" || echo "PVC clean"

kubectl delete secrets --all -n jenkins-ns

kubectl -n jenkins-ns get all,secrets,svc,configmap
# kubectl delete namespace jenkins-ns