FROM jenkins/inbound-agent:latest-alpine-jdk21

USER root

RUN apk update && apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    github-cli

WORKDIR /home/jenkins

# Copy Kaniko executor
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko /kaniko
ENV PATH=$PATH:/kaniko

# Trivy client (for client-server mode - accesses trivy-server in nexus-ns)
RUN set -e; \
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin && \
    trivy --version

# Create kaniko dir
# Fix permissions for kaniko user
RUN mkdir -p /kaniko/.docker && \
    chmod -R 777 /kaniko 