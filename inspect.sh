#!/bin/bash
readonly BUILD_SCRIPT=${BUILD_SCRIPT:-'1'}
shift

# shellcheck source=library.sh
source "${HERA_HOME}"/library.sh

is_defined "${BUILD_SCRIPT}" 'No build script provided' 2

readonly CONTAINER_NAME=$(container_name "${JOB_NAME}" "${BUILD_ID}")

set +u
run_ssh "podman inspect ${CONTAINER_NAME} | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g'"
