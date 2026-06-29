helm uninstall kibana -n monitoring
helm uninstall elasticsearch -n monitoring
helm uninstall logstash -n monitoring
helm uninstall filebeat -n monitoring 
kubectl delete jobs -n monitoring --all
kubectl delete pvc -n monitoring -l app=elasticsearch-master

kubectl -n monitoring get all,secrets,svc,configmap,crd,job,serviceaccount

