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
    
    
    options { timeout(time: 10, unit: 'MINUTES') }
    triggers {
        GenericTrigger(
            genericVariables: [
                // fetch data from webhook payload
                [key: 'REPO_NAME', value: '$.repository.name'],
                [key: 'REPO_URL',  value: '$.repository.clone_url'],
                [key: 'BRANCH',    value: '$.ref'],
                [key: 'COMMIT_SHA',     value: '$.head_commit.id'],      // SHA commit
                [key: 'COMMIT_MESSAGE', value: '$.head_commit.message']
            ],
            token: 'build-token',  // token for all
            causeString: 'Triggered by $REPO_NAME',

            // filter for push in DEV!
            regexpFilterText: '$BRANCH $REPO_NAME',
            regexpFilterExpression: 'refs/heads/DEV (final-frontend-repo|final-backend-repo)'
        )
    }
    stages {
        stage('# ---- print variables from Generic Webhook Plugin---- #') {
            steps {
                sh """ set +x
                    echo "REPO_NAME: ${env.REPO_NAME}"
                    echo "REPO_URL: ${env.REPO_URL}"
                    echo "BRANCH: ${env.BRANCH}"
                    echo "COMMIT_SHA:  ${env.COMMIT_SHA}"
                    echo "COMMIT_MESSAGE: ${env.COMMIT_MESSAGE}"
                """
            }
        }
        stage('Prepare') {
            steps {
                script {
                    // determine IMAGE_NAME and credentialsId based on repo name
                    if (env.REPO_NAME == 'final-frontend-repo') {
                        env.IMAGE_NAME = 'frontend-image'
                        env.GITHUB_CRED = 'github-frontend-cred'
                        env.DEPLOY_APP = 'frontend'
                    } else if (env.REPO_NAME == 'final-backend-repo') {
                        env.IMAGE_NAME = 'backend-image'
                        env.GITHUB_CRED = 'github-backend-cred'
                        env.DEPLOY_APP = 'backend'
                    }
                    echo "Building: ${env.IMAGE_NAME} from ${env.REPO_URL}"
                    echo "Using credentials: ${env.GITHUB_CRED}"
                }
            }
        }
        stage('Clone') {
            steps {
                git branch: 'DEV',
                    url: "${env.REPO_URL}",
                    credentialsId: "${env.GITHUB_CRED}"
            }
        }
        stage('Build & Push') {
            steps {
                sh """
                    export DOCKER_CONFIG=/kaniko/.docker

                        # Copy to a separate folder outside the workspace
                        echo "=== workspace content ==="
                        ls -la
                        
                        echo "=== copying to /tmp ==="
                        cp -r \$(pwd) /tmp/build_context
                        
                        echo "=== /tmp/build_context content ==="
                        ls -la /tmp/build_context
                        
                        echo "=== requirements.txt exists? ==="
                        ls -la /tmp/build_context/requirements.txt || echo "NOT FOUND!"

                        /kaniko/executor \
                            --context /tmp/build_context \
                            --dockerfile /tmp/build_context/Dockerfile \
                            --destination nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA} \
                            --insecure \
                            --skip-tls-verify \
                            --use-new-run \
                            --cache=true \
                            --cache-repo=nexus-service.nexus-ns.svc.cluster.local:8083/kaniko-cache \
                            --snapshot-mode=redo
                    """
            }
        }
        stage('# ---- Trigger cd-pipeline /Job Name/ ---- #') {
            steps {
                build job: 'cd-pipeline', wait: false, 
                parameters: [
                    string(name: 'DEPLOY_APP', value: "${env.DEPLOY_APP}"),
                    string(name: 'COMMIT_SHA', value: "${env.COMMIT_SHA}"),
                    string(name: 'REPO_URL', value: "${env.REPO_URL}"),
                    string(name: 'REPO_NAME', value: "${env.REPO_NAME}")
                ]
            }
        }
    }
}