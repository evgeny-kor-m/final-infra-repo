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
                    echo "DEPLOY_APP: ${params.DEPLOY_APP}"
                    echo "COMMIT_SHA:  ${params.COMMIT_SHA}"
                """
            }
        }
        stage('Check pwd and ls -la') {
            steps {
                sh """
                        ls -la
                        pwd
                    """
            }
        }
        stage('Update Image Tag') {
            steps {
                sh """
                    sed -i 's|${params.DEPLOY_APP}"-image":.*|${params.DEPLOY_APP}"-image":${params.COMMIT_SHA}|g' \
                        ($pwd)/kubernetes/${params.DEPLOY_APP}/02-deployment.yaml

                    echo " ---- Updated file ---- "
                    cat ($pwd)/kubernetes/${params.DEPLOY_APP}/02-deployment.yaml
                """
            }
        }
        stage('Git Push') {
            steps {
                sh '''
                    git add build.log
                    git add ($pwd)/kubernetes/${params.DEPLOY_APP}/02-deployment.yaml
                    git commit -m "CD: update ${params.DEPLOY_APP}-image to ${params.COMMIT_SHA}"
                '''

                withCredentials([gitUsernamePassword(credentialsId: 'github-infra-cred', gitToolName: 'Default')]) {
                    sh 'git push origin HEAD:DEV'
                }
            }
        }
    }
}