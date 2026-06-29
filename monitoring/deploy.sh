kubectl create namespace monitoring
kubectl delete serviceaccount pre-install-kibana-kibana -n monitoring --ignore-not-found
kubectl delete configmap kibana-kibana-helm-scripts -n monitoring --ignore-not-found

helm install elasticsearch elastic/elasticsearch --version 8.5.1 -n monitoring -f ./monitoring/elasticsearch-values.yaml
echo "waiting pod will ready"
kubectl wait --for=condition=ready pod/elasticsearch-master-0 -n monitoring --timeout=120s

helm install logstash elastic/logstash --version 8.5.1 -n monitoring -f ./monitoring/logstash-values.yaml
echo "waiting pod will ready"
kubectl wait --for=condition=ready pod/logstash-0 -n monitoring --timeout=120s

helm install kibana elastic/kibana --version 8.5.1 -n monitoring -f ./monitoring/kibana-values.yaml

helm install filebeat elastic/filebeat --version 8.5.1 -n monitoring -f ./monitoring/filebeat-values.yaml

kubectl -n monitoring get all,secrets,svc,configmap,crd,job,serviceaccount