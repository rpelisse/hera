#!/bin/bash
set +u
readonly PARENT_JOB_NAME=${PARENT_JOB_NAME}
readonly PARENT_JOB_BUILD_ID=${PARENT_JOB_BUILD_ID}
readonly BUILD_PODMAN_IMAGE=${BUILD_PODMAN_IMAGE:-'localhost/automatons'}
readonly JENKINS_HOME_DIR=${JENKINS_HOME_DIR:-'/home/jenkins/'}
readonly JENKINS_ACCOUNT_DIR=${JENKINS_ACCOUNT_DIR:-'/home/jenkins'}
readonly JENKINS_UID=${JENKINS_UID:-'1000'}
readonly JENKINS_GUID=${JENKINS_GUID:-"${JENKINS_UID}"}
readonly JOB_NAME=${JOB_NAME}
readonly BUILD_ID=${BUILD_ID}
readonly CONTAINER_SERVER_HOSTNAME=${CONTAINER_SERVER_HOSTNAME:-'olympus'}
readonly CONTAINER_SERVER_IP=${CONTAINER_SERVER_IP:-'10.88.0.1'}
set -u

add_parent_volume_if_provided() {
  if [ -n "${PARENT_JOB_NAME}" ]; then
    if [ -n "${PARENT_JOB_BUILD_ID}" ]; then
      echo "-v '${JENKINS_HOME_DIR}/jobs/${PARENT_JOB_NAME}/builds/${PARENT_JOB_BUILD_ID}/archive:/parent_job/:ro'"
    else
      echo "Something is wrong PARENT_JOB_NAME: ${PARENT_JOB_NAME} was provided, but not PARENT_JOB_BUILD_ID, abort."
      exit 1
    fi
  fi
}

# shellcheck source=./library.sh
source "${HERA_HOME}"/library.sh

is_defined "${WORKSPACE}" "No WORKSPACE provided." 1
is_dir "${WORKSPACE}" "Workspace provided is not a dir: ${WORKSPACE}" 2
is_defined "${JOB_NAME}" "No JOB_NAME provided." 3
is_defined "${BUILD_ID}" "No BUILD_ID provided." 4
is_defined "${CONTAINER_SERVER_HOSTNAME}" "No hostname provided for the container server"
is_defined "${CONTAINER_SERVER_IP}" 'No IP address provided for the container server'

# When running a job in parallel the workspace folder is not the same as JOB_NAME
readonly JOB_DIR=$(echo "${WORKSPACE}" | sed -e "s;/var/jenkins_home/;${JENKINS_HOME_DIR};")
readonly CONTAINER_TO_RUN_NAME=${CONTAINER_TO_RUN_NAME:-$(container_name "${JOB_NAME}" "${BUILD_ID}")}
readonly CONTAINER_COMMAND=${CONTAINER_COMMAND:-"${WORKSPACE}/hera/wait.sh"}

# shellcheck disable=SC2016
run_ssh "podman run \
            --userns=keep-id -u ${JENKINS_UID}:${JENKINS_GUID} \
            --name "${CONTAINER_TO_RUN_NAME}" \
             --add-host=${CONTAINER_SERVER_HOSTNAME}:${CONTAINER_SERVER_IP}  \
            --rm $(add_parent_volume_if_provided) \
            --workdir ${WORKSPACE} \
            -v "${JOB_DIR}":${WORKSPACE}:rw \
            -v /opt/:/opt/:ro \
            -v "${JENKINS_ACCOUNT_DIR}/.ssh/":/var/jenkins_home/.ssh/:rw \
            -v "${JENKINS_ACCOUNT_DIR}/.gitconfig":/var/jenkins_home/.gitconfig:ro \
            -v "${JENKINS_ACCOUNT_DIR}/.netrc":/var/jenkins_home/.netrc:ro \
	        -d ${BUILD_PODMAN_IMAGE} '${CONTAINER_COMMAND}'"
