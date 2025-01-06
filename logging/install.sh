#!/bin/bash
# Installs Logging Operator and Crds
## Usage: ./install.sh [kubeconfig]

if [ $# -ge 1 ] ; then
  export KUBECONFIG=$1
fi

NS=cattle-logging-system

echo "Creating namespace: $NS"
kubectl create namespace $NS || echo "Namespace $NS already exists."

function check_and_update_kibana_host() {
  echo "Please provide the Kibana Host."

  # Loop until a valid host is entered
  while true; do
    read -p "Enter Kibana Host: " KIBANA_HOST

    # Simple validation for host format (you can enhance this regex for stricter validation)
    if [[ $KIBANA_HOST =~ ^[a-zA-Z0-9.-]+$ ]]; then
      echo "Kibana Host entered: $KIBANA_HOST"
      echo "Note: Please update the global ConfigMap with the same Kibana Host as part of the MOSIP external modules deployment."
      break
    else
      echo "Invalid Kibana Host. Please try again."
    fi
  done
}

check_and_update_kibana_host

function installing_logging() {
  echo "Updating Helm repositories."
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo add banzaicloud-stable https://charts.helm.sh/stable
  helm repo update

  echo "Installing Bitnami Elasticsearch and Kibana istio objects."
  helm -n $NS install elasticsearch mosip/elasticsearch -f es_values.yaml --version 17.9.25 --wait
  echo "Installed Bitnami Elasticsearch and Kibana istio objects."

  KIBANA_NAME=elasticsearch-kibana

  echo "Installing Istio Addons."
  helm -n $NS install istio-addons chart/istio-addons \
    --set kibanaHost=$KIBANA_HOST \
    --set installName=$KIBANA_NAME

  echo "Installing CRDs for Logging Operator."
  helm -n $NS install rancher-logging-crd mosip/rancher-logging-crd --wait
  echo "Installed CRDs for Logging Operator."

  echo "Installing Logging Operator."
  helm -n $NS install rancher-logging mosip/rancher-logging -f values.yaml
  echo "Installed Logging Operator."

  return 0
}

# Set commands for error handling
set -e
set -o errexit   ## Exit the script if any statement returns a non-true return value
set -o nounset   ## Exit the script if you try to use an uninitialized variable
set -o errtrace  # Trace ERR through 'time command' and other functions
set -o pipefail  # Trace ERR through pipes

installing_logging   # Calling the function

