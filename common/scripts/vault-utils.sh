#!/usr/bin/env bash
set -eu

get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

SCRIPT=$(get_abs_filename "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
COMMONPATH=$(dirname "${SCRIPTPATH}")
PATTERNPATH=$(dirname "${COMMONPATH}")

# Parse arguments
if [ $# -lt 1 ]; then
  echo "Specify at least the command ($#): $*"
  exit 1
fi

TASK="${1}"
PATTERN_NAME=${2:-$(basename "`pwd`")}

if [ -z ${TASK} ]; then
	echo "Task is unset"
	exit 1
fi

EXTRA_PLAYBOOK_OPTS="${EXTRA_PLAYBOOK_OPTS:-}"
OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL:-}"
SPIFFE_AUDIENCE="${SPIFFE_AUDIENCE:-}"
SPIFFE_SUBJECT="${SPIFFE_SUBJECT:-}"

if [ -z "${OIDC_DISCOVERY_URL}" ] || [ -z "${SPIFFE_AUDIENCE}" ] || [ -z "${SPIFFE_SUBJECT}" ]; then
  VAULT_JWT_CONFIG="false"
  echo "Vault JWT config is disabled"
else
  VAULT_JWT_CONFIG="true"
  echo "Vault JWT config is enabled"
fi

ansible-playbook -t "${TASK}" \
  -e pattern_name="${PATTERN_NAME}" \
  -e pattern_dir="${PATTERNPATH}" \
  -e vault_jwt_config="${VAULT_JWT_CONFIG}" \
  -e oidc_discovery_url="${OIDC_DISCOVERY_URL}" \
  -e spiffe_audience="${SPIFFE_AUDIENCE}" \
  -e spiffe_subject="${SPIFFE_SUBJECT}" \
  ${EXTRA_PLAYBOOK_OPTS} "rhvp.cluster_utils.vault"
