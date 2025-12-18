#!/usr/bin/env bash

set -euo pipefail

# print log message
log_msg() {
  echo "$(date +'[%Y/%m/%d %H:%M:%S] ') $*"
}

EXTRACT_DIR="$(mktemp -d /tmp/quay-ca-extractor-XXXXXX)"

log_msg "Extracting Ingress CA"
mkdir -p "${EXTRACT_DIR}"

oc extract secret/router-ca -n openshift-ingress-operator \
    --keys=tls.crt --to="${EXTRACT_DIR}" --confirm

CERT_FILE="${EXTRACT_DIR}/tls.crt"

log_msg "Checking Certificate Source"
if [ ! -f "${CERT_FILE}" ]; then
    log_msg "Error: Certificate file not found at ${CERT_FILE}"
    exit 1
fi

log_msg "Source: ${CERT_FILE}"
log_msg "Target Registry: ${REGISTRY_HOST}"

log_msg "Creating ConfigMap '${CM_NAME}' in openshift-config"

oc create configmap "${CM_NAME}" \
    --from-file="${REGISTRY_HOST}=${CERT_FILE}" \
    -n openshift-config

log_msg "Patching Cluster Image Configuration"

oc patch image.config.openshift.io/cluster \
    --type=merge \
    -p "{\"spec\":{\"additionalTrustedCA\":{\"name\":\"${CM_NAME}\"}}}"

log_msg "Configuration applied successfully"