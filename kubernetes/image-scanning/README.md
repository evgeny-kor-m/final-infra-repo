## Image Scanning and Vulnerability Analysis

Trivy remains the right choice because:

It doesn't require a database or server—it's just a binary in the agent pod (critical with 6GB of RAM).
--exit-code 1 provides the desired "fail pipeline" behavior out of the box without any additional logic.
The only free tool that scans both OS layers and application dependencies equally well (Flask backend + React frontend).

https://oneuptime.com/blog/post/2026-02-02-trivy-container-scanning/view  
https://oneuptime.com/blog/post/2026-01-27-trivy-kubernetes-security/view#installing-the-trivy-operator

### Used in Dynamic Jenkins Agent
```
  - name: trivy
    image: aquasec/trivy:0.71.1
    command: ["sleep"]
    args: ["9999999"]
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "300m"
        memory: "400Mi"
```
### trigger to start scan 
```
        stage('Scan stage') {
            steps {
                container('trivy') {
                    script {
                        def scanStatus = sh(
                            script: """
                                trivy image --insecure --severity HIGH,CRITICAL --exit-code 1 \
                                --ignore-unfixed \ 
                                --format json --output trivy-report.json \
                                nexus-service.nexus-ns.svc.cluster.local:8083/${env.IMAGE_NAME}:${env.COMMIT_SHA}
                            """,
                            returnStatus: true
                        )
                        archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                        if (scanStatus != 0) {
                            error("HIGH/CRITICAL vulnerabilities found in ${env.IMAGE_NAME}:${env.COMMIT_SHA}.")
                        }
                    }
                }
            }
        }
# Added --ignore-unfixed \ # show only vulnerabilities that have a patch available
```




kubectl apply -f ./kubernetes/nexus/ -n nexus-ns
kubectl rollout restart deployment/trivy-server -n nexus-ns
kubectl delete deployment/trivy-server -n nexus-ns