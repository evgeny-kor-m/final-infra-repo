FROM jenkins/inbound-agent:latest-alpine-jdk17

USER root

RUN apk update && apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    docker-cli \
    github-cli

WORKDIR /home/jenkins