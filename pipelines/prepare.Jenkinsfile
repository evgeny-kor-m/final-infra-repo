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
    environment {   
                GITHUB_CRED = credentials('github-infra-cred')
                HEAD_BRANCH = "cd/deployments"
                BASE_BRANCH = "main"
             }
    parameters {
                string(name: 'DEPLOY_APP', defaultValue: '', description: 'Changed application name')
                string(name: 'COMMIT_SHA', defaultValue: '', description: 'Commit id from CI')
                string(name: 'REPO_URL', defaultValue: '', description: 'URL repository')
                string(name: 'REPO_NAME', defaultValue: '', description: 'repository name')
    }
    stages {
        stage('# ---- print recieved variables from ci-pipeline ---- #') {
            steps {
                script {
                    def owner = params.REPO_URL.replaceAll('https://github.com/', '').split('/')[0]
                    env.GIT_REPO = "${owner}/${params.REPO_NAME}"
                }
                sh """ set +x
                    echo "DEPLOY_APP: ${params.DEPLOY_APP}"
                    echo "COMMIT_SHA:  ${params.COMMIT_SHA}"
                    echo "REPO_URL: ${params.REPO_URL}"
                    echo "REPO_NAME:  ${params.REPO_NAME}"
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
        stage('Update Image Tag, Git Commit & Push') {
            steps {
                withCredentials([gitUsernamePassword(
                    credentialsId: 'github-infra-cred',
                    gitToolName: 'Default'
                )]) {
                    sh """
                        git config user.email "jenkins@ci.com"
                        git config user.name "Jenkins"

                        git checkout -B ${env.HEAD_BRANCH} origin/${env.BASE_BRANCH}

                        sed -i 's|${params.DEPLOY_APP}-image:.*|${params.DEPLOY_APP}-image:${params.COMMIT_SHA}|g' \
                            kubernetes/${params.DEPLOY_APP}/02-deployment.yaml

                        echo " ---- Updated file ---- "
                        cat kubernetes/${params.DEPLOY_APP}/02-deployment.yaml

                        git add kubernetes/${params.DEPLOY_APP}/02-deployment.yaml
                        git commit -m "CD: update ${params.DEPLOY_APP}-image to ${params.COMMIT_SHA}"

                        git push origin ${env.HEAD_BRANCH} --force
                    """
                }
            }
        }
        stage('# ---- run pr-script ---- #') {
            steps {
                echo "running PR"
                sh """
                    export GH_TOKEN=\$GITHUB_CRED_PSW
                    bash scripts/gh_pr_script.sh \
                        --message "${params.COMMIT_SHA}" \
                        --repo "${env.GIT_REPO}" \
                        --head "${env.HEAD_BRANCH}" \
                        --base "${env.BASE_BRANCH}"
                """
            }
        }
    }
}