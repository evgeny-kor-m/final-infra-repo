#!/bin/bash
# cleanup.sh — full clean

kubectl delete deploy backend-app -n backend

kubectl delete svc --all -n backend

kubectl get all