#!/bin/bash
set -eo pipefail

scriptType() {
  basename "${0}" | sed -e 's/-wrapper.sh//'
}

set +u
readonly SCRIPT_TYPE=$(scriptType)
readonly HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia/"}
readonly HARMONIA_DEBUG=${HARMONIA_DEBUG}
readonly HARMONIA_SCRIPT=${HARMONIA_SCRIPT:-'eap-job.sh'}
readonly BUILD_ID=${BUILD_ID}
readonly JOB_NAME=${JOB_NAME}
readonly PRINT_BUILD_ENV=${PRINT_BUILD_ENV:-'true'}
set -u
readonly HERA_HOME=${HERA_HOME:-"${WORKSPACE}/hera/"}
readonly FAIL_TO_SET_DEFAULT_TO_WORKSPACE_CODE=13

echo "WORKSPACE: ${WORKSPACE}"
echo "HERA_HOME: ${HERA_HOME}"

# shellcheck source=./library.sh
source "${HERA_HOME}/library.sh"

printJobConfig
printEnv

for var in "${HERA_HOME}" "${WORKSPACE}"
do
  is_defined "${var}" 'One of the HOME value or WORKSPACE is undefined'
  is_dir "${var}" 'One of the HOME or the WORKSPACE is not a dir'
done
is_defined "${JOB_NAME}" 'No BUILD_NAME provided'
is_defined "${BUILD_ID}" 'No BUILD_ID provided'

#printJobConfig

cd "${WORKSPACE}" || exit "${FAIL_TO_SET_DEFAULT_TO_WORKSPACE_CODE}"

export USER='jenkins'
#printEnv

is_defined "${HARMONIA_HOME}" 'HARMONIA_HOME is undefined'
is_dir "${HARMONIA_HOME}" "Provided HARMONIA_HOME is invalid: ${HARMONIA_HOME}"

readonly SCRIPT="${HARMONIA_HOME}/${HARMONIA_SCRIPT}"
readonly BUILD_LOG="${HERA_HOME}/build_${BUILD_ID}.log"

if [ "${HARMONIA_DEBUG}" ]; then
  # shellcheck disable=SC2086
  bash -x "${SCRIPT}" 2>&1 | tee "${BUILD_LOG}"
else
  # shellcheck disable=SC2086
  "${SCRIPT}" 2>&1 | tee "${BUILD_LOG}"
fi

readonly BUILD_STATUS="${PIPESTATUS[0]}"
echo "${BUILD_STATUS}" > "${HERA_HOME}/build_${BUILD_ID}_${BUILD_STATUS}.result"
exit "${BUILD_STATUS}"
