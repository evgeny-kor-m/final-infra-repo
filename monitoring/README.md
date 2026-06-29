## Monitoring
https://medium.com/@kayvan.sol2/deploy-elasticsearch-kibana-logstash-with-docker-compose-df518d68731d

<p align="left">
  <img src="pic/ELK.jpg" width="500" alt="view"/>
  <img src="pic/EFLK.jpg" width="500" alt="view"/>
</p>

### Objective:
Deploy a complete monitoring and observability solution.

Requirements:
Deploy ELK Stack inside Kubernetes.

Components:
Elasticsearch
Logstash
Kibana
Metricbeat   
APM Server


### Monitoring Requirements:
The platform must collect:

Metrics - Collect metrics from all Kubernetes components.

Logs - Collect logs from:
Frontend
Backend
Database
Jenkins
ArgoCD
Nexus

Traces - Collect traces across the platform.

### Elasticsearch