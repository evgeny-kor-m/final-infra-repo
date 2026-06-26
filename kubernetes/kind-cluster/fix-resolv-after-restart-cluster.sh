#!/bin/bash

for node in kind-01-control-plane kind-01-worker; do
  docker exec $node bash -c "cat > /etc/resolv.conf << 'EOF'
nameserver 10.96.0.10
nameserver 192.168.65.254
options ndots:5
search default.svc.cluster.local svc.cluster.local cluster.local
EOF"
  docker exec $node systemctl restart containerd
done