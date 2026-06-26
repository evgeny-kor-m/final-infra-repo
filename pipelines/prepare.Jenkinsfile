pipeline {
    agent {
        kubernetes {
        yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins-ns
spec:
  imagePullSecrets:
  - name: nexus-registry-secret
  containers:
  - name: jnlp
    image: nexus-service.nexus-ns.svc.cluster.local:8083/jenkins-inbound-agent-image:latest
    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    volumeMounts:
    - name: kaniko-secret
      mountPath: /kaniko/.docker/config.json
      subPath: config.json
  volumes:
  - name: kaniko-secret
    secret:
      secretName: nexus-registry-secret
      items:
      - key: .dockerconfigjson
        path: config.json
"""
                }
     }
    parameters {
                string(name: 'DEPLOY_APP', defaultValue: '', description: 'Changed application name')
                string(name: 'COMMIT_SHA', defaultValue: '', description: 'Commit id from CI')
    }
    stages {
        stage('# ---- print recieved variables from ci-pipeline ---- #') {
            steps {
                sh """ set +x
                    echo "DEPLOY_APP: ${env.DEPLOY_APP}"
                    echo "COMMIT_SHA:  ${env.COMMIT_SHA}"
                """
            }
        }
    } 
}