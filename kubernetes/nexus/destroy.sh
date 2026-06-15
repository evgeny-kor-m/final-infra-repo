#!/bin/bash
# destroy.sh — database namespace clean

kubectl delete sts nexus -n nexus-ns

kubectl wait --for=delete pod --all -n nexus-ns --timeout=60s

kubectl delete svc nexus-service -n nexus-ns
kubectl delete pvc --all -n  nexus-ns

kubectl wait --for=delete pvc --all -n nexus-ns --timeout=60s
kubectl get pvc -n nexus-ns --no-headers 2>/dev/null | grep -q . && echo "PVC exists!" || echo "PVC clean"

kubectl delete namespace nexus-ns




