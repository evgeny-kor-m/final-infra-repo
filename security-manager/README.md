
### OpenBao
https://openbao.org/docs/platform/k8s/helm/run/

| # | Requirement                                                                     | Status |
|---|---------------------------------------------------------------------------------|--------|
| 1 | Deploy OpenBao into the cluster (Helm/manifests)                                |        |
| 2 | Configure authentication between Kubernetes and the secret manager              |        |
| 3 | Store application credentials in the secret manager                             |        |
| 4 | Inject secrets into workloads                                                   |        |
| 5 | Enable automatic password rotation every 24 hours                               |        |
| 6 | Synchronize rotated secrets to running applications without manual intervention |        |

[!] https://medium.com/@PlatformEnthusiast/the-secret-layer-how-openbao-protects-your-kubernetes-cluster-752549c1c620  
For Enable automatic password every rotation 24h"

#### Deploy 
```
helm repo add openbao https://openbao.github.io/openbao-helm
helm search repo openbao/openbao
helm install openbao openbao/openbao --namespace openbao-ns --create-namespace
kubectl  get all,secrets,svc,configmap -n openbao-ns
```
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
#### UI 
```
kubectl port-forward service/openbao 8200:8200  -n openbao-ns

http://localhost:8200

Namespace :  / (Root) # this is the default
Method    : Token     # this is the only easy way to log in manually (Kubernetes Auth Method configured for pods)
Token     : enter Root Token - s.s6ukuScUSdiepQguWDPkcZ4p.

# To view 
- Secrets -> secret/ -> mongodb — visually view current values ​​(DB_ReadWrite_User, DB_ReadWrite_Pass), KV v2 stores versions history
- Access -> Auth Methods -> kubernetes — visually view the Kubernetes Auth Method configuration.
- Policies — view mongodb-read/mongodb-rotate
```

#### Configure authentication between Kubernetes and OpenBao
```
https://openbao.org/docs/auth/kubernetes/

kubectl exec -it openbao-0 -n openbao-ns -- sh
bao login s.s6ukuScUSdiepQguWDPkcZ4p
bao auth enable kubernetes

# Allows (backend, frontend) pods to authenticate in OpenBao with their own ServiceAccount token, without separate static credentials.

bao write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"
```
#### Store credentials (KV v2)
```
https://openbao.org/docs/concepts/policies/

kubectl port-forward service/openbao 8200:8200  -n openbao-ns

# Chain: default ServiceAccount in namespace backend → role backend-role → policy mongodb-read → secret secret/mongodb.

bao policy write mongodb-read - <<EOF
path "secret/data/mongodb" {
  capabilities = ["read"]
}
EOF

# List all enabled policies:
bao policy list

# kv-v2 static storage
bao secrets enable -path=secret kv-v2

bao kv put secret/mongodb \
    DB_ReadWrite_User="backend_user" \
    DB_ReadWrite_Pass="backend_pass" \
    DB_ReadOnly_User="readonly_user" \
    DB_ReadOnly__Pass="readonly_pass"

# Read the Latest Secret Version:
bao kv get secret/mongodb

bao write auth/kubernetes/role/backend-role \
    bound_service_account_names=default \
    bound_service_account_namespaces=backend \
    policies=mongodb-read \
    ttl=1h
# ttl=1h — OpenBao token lifetime after pod authentication

kubectl exec -it openbao-0 -n openbao-ns -- bao status
```
#### Inject secrets into workloads
```
Note: The sidecar container lives permanently with the application.
vault.hashicorp.com/agent-inject-static-secret-render-interval: "5m" - This annotation tells the sidecar: to check the secret value every 5 minutes manually

Note: OpenBao is Vault-API-compatible, so its Agent Injector still uses the legacy `vault.hashicorp.com/*` annotation prefix.

# deployment.yaml (backend-app)  
...
      annotations:
         # Turn on the injection mechanism
        vault.hashicorp.com/agent-inject: "true"
         # What role should use when logging into OpenBao
        vault.hashicorp.com/role: "backend-role"
         # Where to get the secret in OpenBao and what to name the resulting file (mongodb.env)
        vault.hashicorp.com/agent-inject-secret-mongodb.env: "secret/data/mongodb"
         # How to format file contents
        vault.hashicorp.com/agent-inject-template-mongodb.env: |
          {{- with secret "secret/data/mongodb" -}}
          export DB_ReadWrite_User="{{ .Data.data.DB_ReadWrite_User }}"
          export DB_ReadWrite_Pass="{{ .Data.data.DB_ReadWrite_Pass }}"
          export DB_ReadOnly_User="{{ .Data.data.DB_ReadOnly_User }}"
          export DB_ReadOnly__Pass="{{ .Data.data.DB_ReadOnly__Pass }}"
          {{- end }}
         # This annotation tells the sidecar: to check the secret value every 5 minutes manually
        vault.hashicorp.com/agent-inject-static-secret-render-interval: "5m"
        vault.hashicorp.com/agent-limits-cpu: "100m"
        vault.hashicorp.com/agent-limits-mem: "64Mi"
        vault.hashicorp.com/agent-requests-cpu: "50m"
        vault.hashicorp.com/agent-requests-mem: "32Mi"
         # Ensures the init-container completes (secret file exists) before the main container starts
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
### Execution flow (steps) 
```
1. ArgoCD applies the Deployment manifest to the API Server
   (this is the Deployment object; the annotation lives on its pod template)
                  │
                  ▼
2. Deployment controller creates a ReplicaSet
   ReplicaSet controller creates the actual Pod object
   (admission control intercepts Pod creation, not Deployment/ReplicaSet creation)
                  │
                  ▼
3. The API Server sees a new Pod being created and, per
   MutatingWebhookConfiguration rules, asks openbao-agent-injector:
   "Do you want to change anything in this pod?"
                  │
                  ▼
4. openbao-agent-injector sees agent-inject: "true"
   → adds an init-container (vault-agent-init) AND a sidecar (vault-agent)
   → adds a shared emptyDir volume ("vault-secrets"), mounted into all containers
   → returns the MODIFIED pod manifest to the API Server
   (no secret has been fetched yet — only the pod SPEC has changed)
                  │
                  ▼
5. The pod is scheduled and created WITH the added containers
                  │
                  ▼
6. AT POD STARTUP: init-container runs first
   → logs into OpenBao via Kubernetes Auth (role: backend-role,
     using the pod's own ServiceAccount token)
   → fetches secret/data/mongodb, renders it via the template
   → writes /vault/secrets/mongodb.env, exits
   (agent-init-first ensures this finishes before the main container starts)
                  │
                  ▼
7. backend-container starts: ". /vault/secrets/mongodb.env" loads the vars,
   then "exec python app_backend.py" launches the app
                  │
                  ▼
8. The sidecar (vault-agent) keeps running in the background,
   polling every 5 min (agent-inject-static-secret-render-interval),
   and rewrites the file in place whenever the KV secret changes
   — no pod restart required
```

## 5 & 6. Automatic 24h rotation + sync without manual intervention
```
# ServiceAccount & CronJob (`backend` namespace)
kubectl apply -f security-manager/
kubectl get cronjob,job -n backend
```
### OpenBao policy + Kubernetes Auth role (write access):
```
kubectl exec -it openbao-0 -n openbao-ns -- sh

bao login s.s6ukuScUSdiepQguWDPkcZ4p

bao policy write mongodb-rotate - <<EOF
path "secret/data/mongodb" {
  capabilities = ["read", "create", "update"]
}
EOF

bao write auth/kubernetes/role/rotator-role \
    bound_service_account_names=rotator-sa \
    bound_service_account_namespaces=openbao-ns \
    policies=mongodb-rotate \
    ttl=15m
```
#### `superadmin` is a dedicated MongoDB user (role `userAdminAnyDatabase`) created specifically for credential rotation — not the cluster's root `admin` account.
```
  db.getSiblingDB("admin").createUser({
    user: "superadmin",
    pwd: "superpassw",
    roles: [{ role: "userAdminAnyDatabase", db: "admin" }, { role: "readWrite", db: "admin" }]
  })
```
#### Troubleshooting
```
kubectl get pods -n openbao-ns

kubectl get mutatingwebhookconfiguration -A
kubectl describe mutatingwebhookconfiguration openbao-agent-injector-cfg | grep -A3 "Failure Policy"

kubectl exec -it openbao-0 -n openbao-ns -- bao status

kubectl exec -it openbao-0 -n openbao-ns -- bao read auth/kubernetes/role/backend-role

kubectl logs -n openbao-ns openbao-agent-injector-7f96c5d6c6-q8zm4

Note: Known risk: the injector's auto-TLS certificates are short-lived and require periodic pod restarts (or setting up persistent, longer-lived TLS via cert-manager)—otherwise, the problem will reoccur after a few days of downtime.
```
### Verify end-to-end
```
kubectl describe pod backend-app-5fbc946d87-kbrjd -n backend | grep -A5 "Init Containers"
Init Containers:
  vault-agent-init:
    Container ID:  containerd://f3ae270aa81159c8741707898c5f3566a07f0e748e42410e54b639fb8ad4a045
    Image:         quay.io/openbao/openbao:2.5.5
    Image ID:      quay.io/openbao/openbao@sha256:6150c4a6b62067db6141c8da7a6a6b5763f4f47c315343d0c848b40fecdfd452
    Port:          <none>

kubectl logs backend-app-5fbc946d87-kbrjd -n backend -c backend-container --tail=20

kubectl exec -it openbao-0 -n openbao-ns -- bao kv get secret/mongodb
======= Metadata =======
Key                Value
---                -----
created_time       2026-07-08T14:05:25.218026349Z
version            5

========== Data ==========
Key                  Value
---                  -----
DB_ReadOnly_User     readonly_user
DB_ReadOnly__Pass    dRCdvZrPPCxdTGfzMK0o
DB_ReadWrite_Pass    oG2sPC4WHsvIEWcmSKVW
DB_ReadWrite_User    backend_user

kubectl exec -it backend-app-5fbc946d87-kbrjd -n backend -c backend-container -- cat /vault/secrets/mongodb.env
export DB_ReadWrite_User="backend_user"
export DB_ReadWrite_Pass="oG2sPC4WHsvIEWcmSKVW"
export DB_ReadOnly_User="readonly_user"
export DB_ReadOnly__Pass="dRCdvZrPPCxdTGfzMK0o"

check if application is work
```
#### Manual test run (without waiting for midnight)
```
kubectl get cronjob,job -n backend
kubectl delete job test-rotation-now -n backend

kubectl create job --from=cronjob/mongodb-password-rotator test-rotation-4 -n backend
kubectl get pods -n backend -w

kubectl logs -f job/test-rotation-4 -n backend
kubectl exec -it openbao-0 -n openbao-ns -- bao kv get secret/mongodb

kubectl exec -it backend-app-5fbc946d87-kbrjd -n backend -c backend-container -- cat /vault/secrets/mongodb.env
```




