#!/bin/bash

for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $node ==="
  docker exec $node bash -c "cat > /etc/resolv.conf << 'EOF'
nameserver 10.96.0.10
nameserver 192.168.65.254
options ndots:5
search default.svc.cluster.local svc.cluster.local cluster.local
EOF"
  docker exec $node systemctl restart containerd
  docker exec $node cat /etc/resolv.conf
done