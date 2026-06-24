#!/bin/bash

# Step 1 - Create cluster
kind create cluster --name kind-01 --config kind-config.yaml

# Step 2 - Wait for CoreDNS
echo "Waiting for CoreDNS..."
kubectl wait --for=condition=ready pod \
  -l k8s-app=kube-dns \
  -n kube-system \
  --timeout=60s

# Step 3 - Copy resolv.conf to all nodes
echo "Patching DNS on nodes..."
for node in kind-01-control-plane kind-01-worker kind-01-worker2; do
  docker cp kubernetes/kind-cluster/resolv.conf $node:/etc/resolv.conf
done
# # Step 3 - Fix DNS on nodes AFTER cluster is ready
# echo "Fixing DNS on nodes..."
# for node in kind-01-control-plane kind-01-worker kind-01-worker2; do
#   docker exec $node bash -c "cat > /etc/resolv.conf << 'EOF'
# nameserver 10.96.0.10
# nameserver 192.168.65.254
# options ndots:5
# search default.svc.cluster.local svc.cluster.local cluster.local
# EOF"
# done

echo "DNS fixed! Restarting containerd..."
for node in kind-01-control-plane kind-01-worker kind-01-worker2; do
  docker exec $node systemctl restart containerd
done

echo "Cluster ready!"