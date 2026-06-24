/** 
* Part 2 – CI Pipeline on Infrastructure Server
*/
// pipeline {
//     agent { label 'jenkins-frontend-inbound-agent-label' }
//     environment {    
//              GITHUB_CRED = credentials('github-frontend-cred')
//              }
//     stages {
//         stage('# ---- Prepare GIT_COMMIT_MSG & GIT_REPO ---- #') {
//             steps {
//                 script {
//                     env.GIT_COMMIT_MSG = sh(script: "git log -1 --pretty=%B ${env.GIT_COMMIT}", returnStdout: true).trim()
//                     env.GIT_REPO = sh(script: "echo ${env.GIT_URL} | sed 's|https://github.com/||' | sed 's|\\.git||'", returnStdout: true).trim()
//                 }
//             }
//         }
//     }
// }

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
            regexpFilterText: '$BRANCH',
            regexpFilterExpression: 'refs/heads/DEV'
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
                    // 
                    if (env.REPO_NAME == 'final-frontend-repo') {
                        env.IMAGE_NAME = 'frontend-image'
                    } else if (env.REPO_NAME == 'final-backend-repo') {
                        env.IMAGE_NAME = 'backend-image'
                    }
                    echo "Building: ${env.IMAGE_NAME} from ${env.REPO_URL}"
                }
            }
        }
    }
}