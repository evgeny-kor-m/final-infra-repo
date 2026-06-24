pipeline {
    agent { label 'jenkins-frontend-inbound-agent-label' }
    
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
                    } else if (env.REPO_NAME == 'final-backend-repo') {
                        env.IMAGE_NAME = 'backend-image'
                        env.GITHUB_CRED = 'github-backend-cred'
                    }
                    echo "Building: ${env.IMAGE_NAME} from ${env.REPO_URL}"
                    echo "Using credentials: ${env.GITHUB_CRED}"
                }
            }
        }
        stage('# ---- docker version & print before Clone ---- #') {
            steps {
                  sh 'docker --version'
                  sh '''
                        set +x
                        pwd
                        ls -la
                    '''
            }
        }
        stage('Clone') {
            steps {
                git branch: 'DEV',
                    url: "${env.REPO_URL}",
                    credentialsId: "${env.GITHUB_CRED}"  // 
            }
        }
        stage('# ---- docker version & print after Clone ---- #') {
            steps {
                  sh 'docker --version'
                  sh '''
                        set +x
                        pwd
                        ls -la
                    '''
            }
        }
        stage('Build') {
            steps {
                sh "docker build -t nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA} ."
            }
        }
        stage('Push') {
            steps {
                sh "docker push nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA}"
            }
        }
    }
}