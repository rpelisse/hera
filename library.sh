#!/bin/bash
set +u
readonly HERA_SSH_KEY=${HERA_SSH_KEY}
readonly HERA_HOSTNAME=${HERA_HOSTNAME:-'olympus'}
readonly HERA_USERNAME=${HERA_USERNAME:-'jenkins'}
readonly HERA_SSH_OPTIONS=${HERA_SSH_OPTIONS}
readonly CONTAINER_NAME_PREFIX=${CONTAINER_NAME_PREFIX:-'automaton-slave'}
export TERM=${TERM:-'screen'}
set -u

is_defined() {
  local var
  local msg
  local status

  var=${1}
  msg=${2:-'A required value is missing'}
  status=${3:-'1'}

  if [ -z "${var}" ]; then
    echo "${msg}"
    exit "${status}"
  fi
}

is_dir() {
  local path
  local msg
  local status

  path=${1}
  msg=${2:-'Invalid - not a directory'}
  status=${3:-'1'}

  if [ ! -d "${path}" ]; then
    echo "${msg}"
    exit "${status}"
  fi
}

exists() {
  local path
  local msg
  local status

  path=${1}
  msg=${2:-'File does not exists'}
  status=${3:-'1'}

  if [ ! -e "${path}" ]; then
    echo "${msg}"
    exit "${status}"
  fi
}

is_executable() {
  local path
  local msg
  local status

  path=${1}
  msg=${2:-'File is not executable'}
  status=${3:-'1'}

  if [ ! -x "${path}" ]; then
    echo "${msg}"
    exit "${status}"
  fi
}

run_ssh() {
  local ssh_options

  ssh_options="-o StrictHostKeyChecking=no ${HERA_SSH_OPTIONS}"

  if [ -n "${HERA_SSH_KEY}" ]; then
    exists "${HERA_SSH_KEY}" "Provided path to SSH_KEY does not exists: ${HERA_SSH_KEY}." 667
    ssh_options="${ssh_options} -i ${HERA_SSH_KEY}"
  fi

  is_defined "${HERA_HOSTNAME}" 'Please define env var HERA_HOSTNAME.' 668
  is_defined "${HERA_USERNAME}" 'Please define env var HERA_USERNAME' 669

  # shellcheck disable=SC2086,SC2029
  ssh ${ssh_options} \
      "${HERA_USERNAME}@${HERA_HOSTNAME}"\
      "${@}"
}

container_name() {
  local job_name
  local build_id
  local name_prefix

  job_name=${1// /}
  build_id=${2// /}
  name_prefix=${3:-${CONTAINER_NAME_PREFIX}}

  echo "${name_prefix}-${job_name}-${build_id}"
}


copy_artefact_from_parent_job() {
  local parent_job_dir="${1}"
  local workspace=${2}

  is_defined "${parent_job_dir}" 'No parent job dir provided'
  is_dir "${parent_job_dir}" "Provided parent job dir is not a directory: ${parent_job_dir}"

  echo "parent_job_dir: ${parent_job_dir}"
  echo "Copying artefacts from ${parent_job_dir} to ${workspace}"
  echo -n ' - starting copy at: '
  date +%T
  echo '...'
  rsync -ar --exclude hera/ --exclude harmonia/ "${parent_job_dir}" "${workspace}"
  echo "Done (at $(date +%T))"
  echo 'check if required test dependency are available'
  find "${workspace}" -name '*wildfly-testsuite-shared*' -type d
}

printJobConfig() {
  set +u
  # shellcheck disable=SC2153
  echo "JOB_NAME: ${JOB_NAME}"
  # shellcheck disable=SC2153
  echo "BUILD_ID: ${BUILD_ID}"
  echo "HARMONIA_HOME: ${HARMONIA_HOME}"
  echo "JAVA_HOME: ${JAVA_HOME}"
  echo "MAVEN_HOME: ${MAVEN_HOME}"
  echo "MAVEN_OPTS: ${MAVEN_OPTS}"
  echo "MAVEN_SETTINGS_XML: ${MAVEN_SETTINGS_XML}"
  echo "MAVEN_VERBOSE: ${MAVEN_VERBOSE}"
  if [ -v MAVEN_GOALS ]; then
    echo "MAVEN_GOALS: ${MAVEN_GOALS}"
  fi
  echo "RERUN_FAILING_TESTS: ${RERUN_FAILING_TESTS}"
  if [ -v BUILD_COMMAND ]; then
    echo "BUILD_COMMAND: ${BUILD_COMMAND}"
  fi
  set -u
}

printEnv() {
  if [ -n "${PRINT_BUILD_ENV}" ]; then
    echo "=== ${JOB_NAME} (Build #${BUILD_ID} environnement )==="
    env
    echo '===================================================='
  fi
}

