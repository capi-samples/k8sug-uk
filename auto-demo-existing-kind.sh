#!/usr/bin/env bash

# Check to see if the repo exists already
# NOTE: this is a duplicate in case this script is run directly
if [ -d ./test ]; then
  echo "The test repo directory exists already. Delete it and start again"
  exit 1
fi

# Create keys for admin user
# mkdir keys
# ssh-keygen -f keys/admin

# Add chart repos we are going to use
pei "helm repo add gitea-charts https://dl.gitea.com/charts/"
pei "helm repo add fleet https://rancher.github.io/fleet-helm-charts/"
pei "helm repo add capi-operator https://kubernetes-sigs.github.io/cluster-api-operator"
pe "helm repo update"

# get settings required for fleet
kubectl config view -o json --raw | jq -r '.clusters[].cluster["certificate-authority-data"]' | base64 -d >ca.pem
API_SERVER_URL=$(kubectl config view -o json --raw | jq -r '.clusters[] | select(.name=="kind-k8sug").cluster["server"]')
API_SERVER_CA="ca.pem"

# Install Fleet
pe "helm -n cattle-fleet-system install --create-namespace --wait fleet-crd fleet/fleet-crd"
pe "helm install --create-namespace -n cattle-fleet-system --set apiServerURL=\"$API_SERVER_URL\" --set-file apiServerCA=\"$API_SERVER_CA\" fleet fleet/fleet --wait"

# Install Gitea
pe "helm install gitea gitea-charts/gitea --values gitea_values.yaml --wait"

# For later use
export USERNAME=gitea_admin
export PASSWORD=admin
export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services gitea-http)
export REPO_NAME=test

# Add SSH key to Gitea user
PUB_KEY=$(cat keys/admin.pub)
curl \
  -X POST "http://$NODE_IP:$NODE_PORT/api/v1/user/keys" \
  -H "accept: application/json" \
  -u $USERNAME:$PASSWORD \
  -H "Content-Type: application/json" \
  -d "{\"key\": \"$PUB_KEY\", \"read_only\": false, \"title\": \"key1\" }" \
  -i

# Setup gitea user
curl \
  -X POST "http://$NODE_IP:$NODE_PORT/api/v1/user/repos" \
  -H "accept: application/json" \
  -u $USERNAME:$PASSWORD \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$REPO_NAME\", \"auto_init\": true}" \
  -i

# Add git auth secret
pe "kubectl create secret generic basic-auth-secret -n fleet-local --type=kubernetes.io/basic-auth --from-literal=username=$USERNAME --from-literal=password=$PASSWORD"

# Add our git repo
cat <<EOF >>./repo.yaml
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: fleet-repo
spec:
  repo: http://$NODE_IP:$NODE_PORT/$USERNAME/$REPO_NAME.git
  branch: main
  forceSyncGeneration: 1
  clientSecretName: basic-auth-secret
EOF

pe "$EDITOR repo.yaml"
pe "kubectl apply -n fleet-local -f repo.yaml"

# Install CAPI operator
pe "helm install capi-operator capi-operator/cluster-api-operator --create-namespace -n capi-operator-system --set cert-manager.enabled=true --wait"

export GITEA_URL="http://$USERNAME:$PASSWORD@$NODE_IP:$NODE_PORT"
pe "xdg-open $GITEA_URL"

export GIT_URL="http://$USERNAME:$PASSWORD@$NODE_IP:$NODE_PORT/$USERNAME/$REPO_NAME.git"

# Clone the test repo
pe "git clone $GIT_URL"
pei "cd test"

# Install CAPI providers
# equivalent of doing clusterctl init
pe "mkdir mgmt"
pe "cp ../data/providers.yaml mgmt/"
pei "git add ."
pei "git commit -m \"Add CAPI providers\""
pe "git push"

# Create a child cluster
pe "mkdir clusters"
pe "cp ../data/cluster.yaml clusters/"
pei "git add ."
pei "git commit -m \"Add cluster definition\""
pe "git push"
pei "echo \"Explore child cluster\""

# Add kindnet CNI using CRS
pe "mkdir crs"
pe "cp ../data/crs.yaml crs/"
pei "git add ."
pei "git commit -m \"Add kindet crs\""
pe "git push"
pei "echo \"Explore child cluster\""

# Deploy CAPI Helm addon provider
pe "cp ../data/addon_provider.yaml mgmt/"
pei "git add ."
pei "git commit -m \"Add helm addon provider\""
pe "git push"

# Deploy app to child cluster based on label
pe "mkdir apps"
pe "cp ../data/addon_app.yaml apps/"
pei "git add ."
pei "git commit -m \"Add app to bde deployed via label\""
pe "git push"
pei "echo \"Explore child cluster\""

# Register child cluster with fleet
pe "cp ../data/fleet_cluster.yaml clusters/"
pei "git add ."
pei "git commit -m \"Register child cluster with fleet\""
pe "git push"

# Create "dev cluster group
pe "cp ../data/dev_cluster_group.yaml mgmt/"
pei "git add ."
pei "git commit -m \"Create dev cluster group\""
pe "git push"

# Deploy nginx to all dev clusters
pe "cp ../data/nginx_bundle.yaml apps/"
pei "git add ."
pei "git commit -m \"Add ngnix to dev clusters\""
pe "git push"

# scale the workers to 3
pe "echo \"Scale workers to 3\""
pe "$EDITOR clusters/cluster.yaml"
pei "git add ."
pei "git commit -m \"Scale workers to 3\""
pe "git push"

# Upgrade the control plane to v1.28.6
pe "echo \"Upgrade Control Plane v1.28.6\""
pe "$EDITOR clusters/cluster.yaml"
pei "git add ."
pei "git commit -m \"Upgrade k8s version\""
pe "git push"

# Add second cluster and watch everything get deployed
pe "cp ../data/cluster2.yaml clusters/"
pei "git add ."
pei "git commit -m \"Add 2nd cluster definition\""
pe "git push"
pei "echo \"Explore child cluster\""
