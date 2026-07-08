
### OpenBao
https://openbao.org/docs/platform/k8s/helm/run/

[!] https://medium.com/@PlatformEnthusiast/the-secret-layer-how-openbao-protects-your-kubernetes-cluster-752549c1c620  
For Enable automatic password every rotation 24h" and "synchronized without manual intervention need the Database Secrets Engine  

#### Deploy 
helm repo add openbao https://openbao.github.io/openbao-helm
helm search repo openbao/openbao
helm install openbao openbao/openbao --namespace openbao-ns --create-namespace

##### Initialize and unseal OpenBao
```
kubectl exec -it openbao-0 -n openbao-ns -- bao status
kubectl exec -ti openbao-0 -n openbao-ns -- bao operator init
<!-- Unseal Key 1: PsRwysYrHBUKQeQFfMMilvpC6hSWde7dh5SK4NOFLjaH
Unseal Key 1: PsRwysYrHBUKQeQFfMMilvpC6hSWde7dh5SK4NOFLjaH  
Unseal Key 2: pB9DCbHbAjTNSKveYVCvM2NHXEcfRkeLA6wLitDIVNJ3  
Unseal Key 3: jYtrQFtEzvSyRslxoZQyYSuOuiEAAuLXKxQ8cz0hl+aC  
Unseal Key 4: E7YxtG14JKg08xm9j0wKg0MkAfZJWThEv9Upv2w9SPAV  
Unseal Key 5: +7YYQamtHifnsQohChO5gtIPrPEMyZgsLco1w9hzJvFg  
  
Initial Root Token: s.s6ukuScUSdiepQguWDPkcZ4p  
 -->

Unseal the OpenBao server with the key shares until the key threshold is met:
kubectl exec -it openbao-0 -n openbao-ns -- bao operator unseal PsRwysYrHBUKQeQFfMMilvpC6hSWde7dh5SK4NOFLjaH
kubectl exec -it openbao-0 -n openbao-ns -- bao operator unseal pB9DCbHbAjTNSKveYVCvM2NHXEcfRkeLA6wLitDIVNJ3
kubectl exec -it openbao-0 -n openbao-ns -- bao operator unseal jYtrQFtEzvSyRslxoZQyYSuOuiEAAuLXKxQ8cz0hl+aC
```
#### Configure authentication between Kubernetes and the secret manager
```
https://openbao.org/docs/auth/kubernetes/

kubectl exec -it openbao-0 -n openbao-ns -- sh
bao login s.s6ukuScUSdiepQguWDPkcZ4p
bao auth enable kubernetes
# Allows (backend, frontend) pods to authenticate in OpenBao with their own ServiceAccount token, without separate static credentials.
bao write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"
```
#### Store credentials
```
https://openbao.org/docs/concepts/policies/

# default ServiceAccount in namespace backend → role backend-role → policy mongodb-read → secret secret/mongodb.

bao policy write mongodb-read - <<EOF
path "secret/data/mongodb" {
  capabilities = ["read"]
}
EOF

# kv-v2 static storage
bao secrets enable -path=secret kv-v2

bao kv put secret/mongodb \
    DB_ReadWrite_User="backend_user" \
    DB_ReadWrite_Pass="backend_pass" \
    DB_ReadOnly_User="readonly_user" \
    DB_ReadOnly__Pass="readonly_pass"

bao write auth/kubernetes/role/backend-role \
    bound_service_account_names=default \
    bound_service_account_namespaces=backend \
    policies=mongodb-read \
    ttl=1h
# ttl=1h — OpenBao token lifetime after pod authentication
```
#### Inject into workloads
```
# in deployment.yaml
...
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        # What role should I use when logging into OpenBao
        vault.hashicorp.com/role: "backend-role"
        # Where to get the secret and what to name the resulting file (mongodb.env)
        vault.hashicorp.com/agent-inject-secret-mongodb.env: "secret/data/mongodb"
        # How to format file contents
        vault.hashicorp.com/agent-inject-template-mongodb.env: |
          {{- with secret "secret/data/mongodb" -}}
          export DB_ReadWrite_User="{{ .Data.data.DB_ReadWrite_User }}"
          export DB_ReadWrite_Pass="{{ .Data.data.DB_ReadWrite_Pass }}"
          export DB_ReadOnly_User="{{ .Data.data.DB_ReadOnly_User }}"
          export DB_ReadOnly__Pass="{{ .Data.data.DB_ReadOnly__Pass }}"
          {{- end }}
        vault.hashicorp.com/agent-limits-cpu: "100m"
        vault.hashicorp.com/agent-limits-mem: "64Mi"
        vault.hashicorp.com/agent-requests-cpu: "50m"
        vault.hashicorp.com/agent-requests-mem: "32Mi"
        # ensures that the init-container will definitely complete before the main container starts
        vault.hashicorp.com/agent-init-first: "true"
...
        command: ["/bin/sh", "-c"]
        args:
          - |
            . /vault/secrets/mongodb.env
            exec python app_backend.py
```
#### Check :
```
kubectl exec -it backend-app-6c665f859d-n8gqp -n backend -c backend-container -- cat /vault/secrets/mongodb.env
kubectl logs backend-app-6c665f859d-n8gqp -n backend -c backend-container
```
#### How it works (steps) 
```
1. ArgoCD applies the Deployment manifest to the API Server
   (this is NOT the Pod itself — it's the Deployment object,
   which has the annotation on its pod template)
                  │
                  ▼
2. Deployment controller creates a ReplicaSet
   ReplicaSet controller creates the actual Pod object
   (this is the moment the annotation actually matters —
   admission control only intercepts Pod creation, not Deployment/ReplicaSet)
                  │
                  ▼
3. The Kubernetes API Server sees a new Pod being created
   and — per MutatingWebhookConfiguration rules — must ask
   openbao-agent-injector: "Do you want to change anything in this pod?"
   (this happens BEFORE the pod is persisted/scheduled)
                  │
                  ▼
4. openbao-agent-injector sees the annotation agent-inject: "true"
   → generates ADDITIONAL containers in the pod spec on the fly:
     - init-container (vault-agent-init)
     - optionally a sidecar (vault-agent), if secret refresh is needed
   → adds a shared emptyDir volume ("vault-secrets") mounted into all containers
   → returns the MODIFIED pod manifest to the API Server
   (at this point, NO actual secret has been fetched yet —
    only the pod SPEC has been changed)
                  │
                  ▼
5. The pod is scheduled and actually created WITH the added containers
                  │
                  ▼
6. AT POD STARTUP: the init-container runs FIRST
   → logs into OpenBao via Kubernetes Auth
     (using role: backend-role from the annotation,
      authenticating with the pod's own ServiceAccount token)
   → fetches secret/data/mongodb
   → renders it using the template from agent-inject-template-mongodb.env
   → writes the result to /vault/secrets/mongodb.env on the shared volume
   → exits (agent-init-first: "true" ensures this completes first)
                  │
                  ▼
7. The main container (backend-container) starts,
   reads /vault/secrets/mongodb.env, and launches the application
```



### Database Secrets Engine

#### How it works mechanically (steps)
```
1. Configure Database Secrets Engine, giving OpenBao admin access to MongoDB (admin credentials that can create users)
                    │
                    ▼
2. Create a "role" (e.g., backend-db-role) that describes:
- what permissions the generated user should have (readWrite, etc.)
- TTL = 24h (default_ttl)
                    │
                    ▼
3. When a pod requests a credential (bao read database/creds/backend-db-role):
OpenBao itself logs into MongoDB as admin
→ It itself creates a new temporary user (random name + random password)
→ returns these credentials to the pod
                    │
                    ▼
4. After 24 hours (TTL expired):
OpenBao itself Logs into MongoDB as admin
→ Deletes this temporary user (revoke)
→ If the pod requests credentials again, it will receive a BRAND NEW user
```
