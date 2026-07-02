
# scale-down-argo-jenkins-nexus 
# Switch to Scenario B (Monitoring): CI/CD + ArgoCD (StatefulSet + few Deployment)
kubectl scale statefulset mongodb -n database --replicas=1
kubectl scale statefulset jenkins -n jenkins-ns --replicas=0
kubectl scale statefulset nexus -n nexus-ns --replicas=0
kubectl scale statefulset argocd-application-controller -n argocd --replicas=0
kubectl scale deployment argocd-server argocd-repo-server argocd-dex-server argocd-redis argocd-applicationset-controller argocd-notifications-controller -n argocd --replicas=0

# scale-up EFLK
kubectl scale statefulset elasticsearch-master -n monitoring --replicas=1
kubectl scale statefulset logstash-logstash -n monitoring --replicas=1
kubectl scale deployment kibana-kibana -n monitoring --replicas=1
kubectl scale deployment apm-server-apm-server -n monitoring --replicas=1
kubectl scale deployment metricbeat-kube-state-metrics -n monitoring --replicas=1
kubectl scale deployment metricbeat-metricbeat-metrics -n monitoring --replicas=1

# DaemonSet:
kubectl patch daemonset filebeat-filebeat -n monitoring \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux"}}}}}'
kubectl patch daemonset metricbeat-metricbeat -n monitoring \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux"}}}}}'