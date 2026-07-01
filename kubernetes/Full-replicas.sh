# Final - restore full replicas:
kubectl scale deployment frontend-app -n frontend --replicas=5
kubectl scale deployment backend-app -n backend --replicas=5
kubectl scale statefulset mongodb -n database --replicas=3