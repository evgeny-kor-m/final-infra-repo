#!/bin/bash
# cleanup.sh — full clean

kubectl delete sts mongodb -n database
kubectl delete deploy mongo-express -n database

kubectl wait --for=delete pod --all -n database --timeout=60s

kubectl delete pvc --all -n database

kubectl wait --for=delete pvc --all -n database --timeout=60s
kubectl get pvc -n database --no-headers 2>/dev/null | grep -q . && echo "PVC exists!" || echo "PVC clean"

kubectl delete namespace database