Schema:
browser
  |
  | http://localhost:80
  |
  ▼
ingress-nginx (control-plane, port 80)
  |
  |── /        → frontend-service:3000     (namespace: frontend)
  |── /api/*   → backend-proxy:5000        (namespace: frontend, type: ExternalName)
                      |
                      ▼ (DNS alias)
               backend-service.backend.svc.cluster.local:5000
config.js changed on:
javascriptwindow.APP_CONFIG = {
  API_URL: '/api' 
}

### 1. Install ingress-nginx controller:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl apply -f kubernetes/ingress/backend-proxy-svc.yaml
kubectl apply -f kubernetes/ingress/ingress.yaml
kubectl apply -f kubernetes/ingress/frontend-cm.yaml 
kubectl rollout restart deployment frontend-app -n frontend

http://localhost:80

## Check 
kubectl get pods -n ingress-nginx
kubectl get ingress -n frontend