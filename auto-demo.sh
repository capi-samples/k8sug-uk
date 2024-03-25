#!/usr/bin/env bash

# Include the magic
. demo-magic.sh

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

# Clear the screen before starting
clear

pe "echo 'Create the management cluster'"

export LOCAL_IP=$(ip -4 -j route list default | jq -r .[0].prefsrc)

rm kind.yaml
cat <<EOF >>./kind.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8sug
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
networking:
  apiServerAddress: "$LOCAL_IP"
EOF

# Create cluster for the management cluster
kind create cluster --config kind.yaml
kubectl rollout status deployment coredns -n kube-system --timeout=90s

pe "clear"

. auto-demo-existing-kind.sh
