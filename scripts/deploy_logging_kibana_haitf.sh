#!/bin/bash
set -x

# Get absolute path for script and root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."
CONFIG_DIR="${ROOT_DIR}/config"

# Source common libraries and env variables
source ${ROOT_DIR}/scripts/common.sh

HELM_CHARTS_REPO_ELASTIC="${HELM_CHARTS_REPO_ELASTIC:-https://helm.elastic.co}"

${SCRIPT_DIR}/k8s/install_helm.sh

# Allow overriding the app name with an env var
repo_name="${HELM_ELASTIC_NAME:-elastic}"
app_name="${KIBANA_APP_NAME:-kibana}"
app_version="${ELASTIC_VERSION:-7.10.2}"

# Allow overriding config dir to look in
export KUBEFLOW_DEEPOPS_KIBANA_CONFIG="${KUBEFLOW_DEEPOPS_KIBANA_CONFIG:-${CONFIG_DIR}/files/logging/kibana}"
export KIBANA_CUSTOM_VALUES="${KIBANA_CUSTOM_VALUES:-${KUBEFLOW_DEEPOPS_KIBANA_CONFIG}/values-haitf.yaml}"


if [ ! -d "${DEEPOPS_CONFIG_DIR}" ]; then
	echo "Can't find configuration in ${DEEPOPS_CONFIG_DIR}"
	echo "Please set DEEPOPS_CONFIG_DIR env variable to point to config location"
	exit 1
fi

if ! kubectl version ; then
    echo "Unable to talk to Kubernetes API"
    exit 1
fi

# Add Helm bitnami repo if it doesn't exist
if ! helm repo list | grep ${repo_name} >/dev/null 2>&1 ; then
	helm repo add ${repo_name} "${HELM_CHARTS_REPO_ELASTIC}"
fi

# Set up the ingress controller
if ! helm status "${app_name}" >/dev/null 2>&1; then
	helm repo update
	helm upgrade --install --wait "${app_name}" --version ${app_version} ${repo_name}/${app_name} -f ${KIBANA_CUSTOM_VALUES} --create-namespace --namespace logging
fi
