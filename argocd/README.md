## ArgoCD
###
```
https://medium.com/@kittipat_1413/advanced-deployment-strategies-using-applicationsets-and-application-of-applications-in-argocd-e01774e10561
https://oneuptime.com/blog/post/2026-02-26-argocd-application-declarative-yaml/view
https://oneuptime.com/blog/post/2026-02-02-argocd-applications/view

kubectl create namespace argocd

kubectl apply -f kubernetes/limit-quotas/argocd.yaml

# Install crd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.4/manifests/crds/applicationset-crd.yaml --server-side
# Check
kubectl get crd | grep argoproj
    applications.argoproj.io      2026-06-28T08:49:17Z
    applicationsets.argoproj.io   2026-06-28T12:08:24Z
    appprojects.argoproj.io       2026-06-28T08:49:17Z

# Run ArgoCD manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.4/manifests/install.yaml --server-side --force-conflicts
kubectl -n argocd get all,secrets,svc,configmap,crd,application

# Run the NodePort locally
# kubectl patch svc argocd-server -n argocd   -p '{"spec": {"type": "NodePort"}}'
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30004, "protocol": "TCP", "name": "http"}]}}'
https://localhost:30004/

kubectl get svc -n argocd
kubectl get svc -n argocd -o wide --watch
# kubectl port-forward svc/argocd-server -n argocd 8085:443

# Go to the Browser and login to the ArgoCD
# http://localhost:8085

User: admin
Password: from command (2LJ-PAcQxifE6yP3)

# Generate the password and type into login page of argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Install secret
kubectl apply -f ./kubernetes/secrets/infra-repo-secret.yaml
# Forced applying secret
kubectl annotate application frontend-app -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite

# Check ststus
kubectl get application -n argocd
    NAME           SYNC STATUS   HEALTH STATUS
    frontend-app   Synced        Healthy

# Install applications
kubectl apply -f ./argocd/frontend-app.yaml
kubectl apply -f ./argocd/backend-app.yaml

```