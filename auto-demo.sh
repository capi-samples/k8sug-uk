#!/usr/bin/env bash

# Include the magic
. demo-magic.sh

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"

# Check to see if the repo exists already
if [ -d ./test ]; then
  echo "The test repo directory exists already. Delete it and start again"
  exit 1
fi

# Clear the screen before starting
clear

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
pe "kind create cluster --config kind.yaml"
kubectl rollout status deployment coredns -n kube-system --timeout=90s

pe "clear"

. auto-demo-existing-kind.sh
