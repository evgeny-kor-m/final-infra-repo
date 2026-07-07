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
    image: nexus-service.nexus-ns.svc.cluster.local:8083/jenkins-inbound-agent-image:v5
    imagePullPolicy: Always
    env:
      - name: JAVA_OPTS
        value: "-Djdk.lang.Process.launchMechanism=VFORK"
    resources:
      requests:
        cpu: "300m"
        memory: "768Mi"
      limits:
        cpu: "1000m"
        memory: "1200Mi"
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
        stage('Scan stage') {
            steps {
                script {
                    def scanStatus = sh(
                        script: """
                            trivy client \
                            --remote http://trivy-service.nexus-ns.svc.cluster.local:4954 \
                            image \
                            --severity HIGH,CRITICAL \
                            --exit-code 1 \
                            --format json \
                            --output trivy-report.json \
                            --insecure \
                            nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA}
                        """,
                        returnStatus: true
                    )
                    if (scanStatus == 127) {
                        error("Trivy binary not found — check agent image build.")
                    } else if (scanStatus != 0) {
                        archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                        error("HIGH/CRITICAL vulnerabilities found in ${env.IMAGE_NAME}:${env.COMMIT_SHA}.")
                    }
                }
            }
        }
        stage('# ---- Trigger cd-pipeline /Job Name/ ---- #') {
            steps {
                build job: 'cd-pipeline', wait: false, 
                parameters: [
                    string(name: 'DEPLOY_APP', value: "${env.DEPLOY_APP}"),
                    string(name: 'COMMIT_SHA', value: "${env.COMMIT_SHA}")
                ]
            }
        }
    }
    post {
    failure {
        emailext (
            subject: "Security Scan Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: """
                <p>High/Critical vulnerability detected in image:</p>
                <p><b>${env.IMAGE_NAME}:${env.COMMIT_SHA}</b></p>
                <p>Deploy has been blocked — cd-pipeline was NOT triggered.</p>
                <p>Build log: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                <p>See attached Trivy report for details.</p>
            """,
            mimeType: 'text/html',
            to: "evgeny.korchev@gmail.com",
            attachmentsPattern: 'trivy-report.json'
        )
    }
    }
}