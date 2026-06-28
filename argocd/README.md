## ArgoCD
```
kubectl create namespace argocd

# Install crd
kubectl apply -f ./argocd/applicationset-crd.yaml --server-side
# Check
kubectl get crd | grep argoproj
    applications.argoproj.io      2026-06-28T08:49:17Z
    applicationsets.argoproj.io   2026-06-28T12:08:24Z
    appprojects.argoproj.io       2026-06-28T08:49:17Z

# Run ArgoCD manifest
kubectl apply -n argocd -f ./argocd/install.yaml
kubectl -n argocd get all,secrets,svc,configmap,crd

# Run the NodePort locally
kubectl patch svc argocd-server -n argocd   -p '{"spec": {"type": "NodePort"}}'
kubectl get svc -n argocd
kubectl get svc -n argocd -o wide --watch
kubectl port-forward svc/argocd-server -n argocd 8085:443

# Go to the Browser and login to the ArgoCD
 http://localhost:8085

User: admin
Password: from command (DylNriEKQEa8k-nm)

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