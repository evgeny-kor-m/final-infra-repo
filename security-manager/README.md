
### OpenBao
https://openbao.org/docs/platform/k8s/helm/run/

[!] https://medium.com/@PlatformEnthusiast/the-secret-layer-how-openbao-protects-your-kubernetes-cluster-752549c1c620  
For Enable automatic password every rotation 24h" and "synchronized without manual intervention need the Database Secrets Engine  

#### install
helm repo add openbao https://openbao.github.io/openbao-helm
helm search repo openbao/openbao
helm install openbao openbao/openbao --namespace openbao-ns --create-namespace

##### Initialize and unseal OpenBao
kubectl exec -it openbao-0 -n openbao-ns -- bao status
kubectl exec -ti openbao-0 -n openbao-ns -- bao operator init
<!-- Unseal Key 1: PsRwysYrHBUKQeQFfMMilvpC6hSWde7dh5SK4NOFLjaH
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

#### Configure authentication between Kubernetes and the secret manager
```
https://openbao.org/docs/auth/kubernetes/

kubectl exec -it openbao-0 -n openbao-ns -- sh
bao login s.s6ukuScUSdiepQguWDPkcZ4p
bao auth enable kubernetes
# Allows (backend, frontend) pods to authenticate in OpenBao with their own ServiceAccount token, without separate static credentials.
bao write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

bao policy write mongodb-read - <<EOF
path "secret/data/mongodb" {
  capabilities = ["read"]
}
EOF
bao secrets enable -path=secret kv-v2
bao kv put secret/mongodb \
    DB_ReadWrite_User="rw_user" \
    DB_ReadWrite_Pass="rw_pass_123" \
    DB_ReadOnly_User="ro_user" \
    DB_ReadOnly__Pass="ro_pass_123"
bao write auth/kubernetes/role/backend-role \
    bound_service_account_names=default \
    bound_service_account_namespaces=backend \
    policies=mongodb-read \
    ttl=1h
# default ServiceAccount in namespace backend → role backend-role → policy mongodb-read → секрет secret/mongodb.
```
#### Inject secrets into workloads
1. OpenBao Agent Injector (Vault-compatible sidecar injector that automatically mounts secrets as files in pods via annotations).  
2. External Secrets Operator (ESO) + OpenBao as a backend — fetches secrets and creates native K8s Secrets, synchronizing regularly.  
Vault/OpenBao Agent Injector:  

#### 


3. Хранение секретов — KV или Database secrets engine:
bashbao secrets enable -path=secret kv-v2
bao kv put secret/mongodb password="..." username="..."
Для настоящей авто-ротации (не просто хранения) — лучше Database Secrets Engine, который умеет сам генерировать новые креды для MongoDB по расписанию:
bashbao secrets enable database
bao write database/config/mongodb \
  plugin_name=mongodb-database-plugin \
  connection_url="mongodb://{{username}}:{{password}}@mongodb-0.mongodb:27017/admin" \
  allowed_roles="app-role"
bao write database/roles/app-role \
  db_name=mongodb \
  creation_statements='{"roles": [{"role": "readWrite"}]}' \
  default_ttl="24h" \
  max_ttl="24h"
default_ttl="24h" — это и есть требуемая "automatic password rotation every 24 hours": каждые 24 часа lease истекает, OpenBao автоматически отзывает старые креды и выдаёт новые при следующем запросе.
4. Injection в workloads — два практичных варианта:

OpenBao Agent Injector (Vault-совместимый sidecar-инжектор, автоматически монтирует секреты как файлы в под через аннотации).
External Secrets Operator (ESO) + OpenBao как backend — тянет секреты и создаёт нативные K8s Secret'ы, регулярно синхронизируя.

5. Синхронизация без ручного вмешательства — ESO при настроенном refreshInterval (например, 1h) сам подтягивает новые креды из OpenBao и обновляет K8s Secret, на который смотрит твой Deployment — при следующем цикле пересоздания пода (или через reloader-контроллер) приложение подхватывает новые креды автоматически.
Важное предупреждение по ресурсам, раз уже сталкивался с этим на Trivy: OpenBao + ESO — это минимум два новых постоянных компонента в и без того плотном 6GB кластере. Прежде чем начинать реализацию, стоит явно проверить оставшийся RAM-бюджет по всем namespace, иначе рискуешь повторить длинную сессию отладки quota/OOM, как с Trivy Server.