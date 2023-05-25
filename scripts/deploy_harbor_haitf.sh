#!/bin/bash
set -x

# Get absolute path for script and root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."
CONFIG_DIR="${ROOT_DIR}/config"

# Source common libraries and env variables
source ${ROOT_DIR}/scripts/common.sh

HELM_CHARTS_REPO_HARBOR="${HELM_CHARTS_REPO_HARBOR:-https://helm.goharbor.io}"

# Define configuration we're injecting into the manifests location
export KUBEFLOW_DEEPOPS_CONFIG_DIR="${KUBEFLOW_DEEPOPS_CONFIG_DIR:-${CONFIG_DIR}/files/harbor}"
export KUBEFLOW_DEEPOPS_HARBOR_CONFIG="${KUBEFLOW_DEEPOPS_HARBOR_CONFIG:-${KUBEFLOW_DEEPOPS_CONFIG_DIR}/values-haitf.yaml}"

${SCRIPT_DIR}/k8s/install_helm.sh

# Allow overriding the app name with an env var
app_name="${HARBOR_APP_NAME:-harbor}"

# Allow overriding config dir to look in
DEEPOPS_CONFIG_DIR=${DEEPOPS_CONFIG_DIR:-"${ROOT_DIR}/config"}

if [ ! -d "${DEEPOPS_CONFIG_DIR}" ]; then
	echo "Can't find configuration in ${DEEPOPS_CONFIG_DIR}"
	echo "Please set DEEPOPS_CONFIG_DIR env variable to point to config location"
	exit 1
fi

if ! kubectl version ; then
    echo "Unable to talk to Kubernetes API"
    exit 1
fi

# Add Helm harbor repo if it doesn't exist
if ! helm repo list | grep harbor >/dev/null 2>&1 ; then
	helm repo add harbor "${HELM_CHARTS_REPO_HARBOR}"
fi

# Set up the ingress controller
if ! helm status "${app_name}" >/dev/null 2>&1; then
	helm repo update
	helm upgrade --install --wait "${app_name}" harbor/harbor --create-namespace --namespace harbor -f ${KUBEFLOW_DEEPOPS_HARBOR_CONFIG}
fi
