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

# Create kaniko dir
# Fix permissions for jenkins user
RUN mkdir -p /kaniko/.docker && \
    chown -R jenkins:jenkins /kaniko  

USER jenkins