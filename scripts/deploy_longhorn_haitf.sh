#!/bin/bash
set -x

# Get absolute path for script and root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."
CONFIG_DIR="${ROOT_DIR}/config"

# Source common libraries and env variables
source ${ROOT_DIR}/scripts/common.sh

HELM_CHARTS_REPO_LONGHORN="${HELM_CHARTS_REPO_LONGHORN:-https://charts.longhorn.io}"

# Define configuration we're injecting into the manifests location
export KUBEFLOW_DEEPOPS_CONFIG_DIR="${KUBEFLOW_DEEPOPS_CONFIG_DIR:-${CONFIG_DIR}/files/longhorn}"
export KUBEFLOW_DEEPOPS_LONGHORN_CONFIG="${KUBEFLOW_DEEPOPS_LONGHORN_CONFIG:-${KUBEFLOW_DEEPOPS_CONFIG_DIR}/values-haitf.yaml}"

${SCRIPT_DIR}/k8s/install_helm.sh

# Allow overriding the app name with an env var
app_name="${LONGHORN_APP_NAME:-longhorn}"

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

# Add Helm longhorn repo if it doesn't exist
if ! helm repo list | grep longhorn >/dev/null 2>&1 ; then
	helm repo add longhorn "${HELM_CHARTS_REPO_LONGHORN}"
fi

# Set up the ingress controller
if ! helm status "${app_name}" >/dev/null 2>&1; then
	helm repo update
	helm upgrade --install --wait "${app_name}" longhorn/longhorn --create-namespace --namespace longhorn-system -f ${KUBEFLOW_DEEPOPS_LONGHORN_CONFIG}
fi
