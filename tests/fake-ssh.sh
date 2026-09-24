#!/bin/bash
# Fake ssh used by the test-suite.
#
# git calls: ssh [options] git@host "git-upload-pack 'owner/repo.git'"
# We ignore the host and run the git server command against a local bare
# repository found under ${MOCK_GIT_ROOT}/owner/repo.git instead.
set -euo pipefail

command_line="${*: -1}"
command_line="${command_line//\'/}"
# shellcheck disable=SC2086
set -- ${command_line}

service="${1#git-}"
repository="${MOCK_GIT_ROOT:?MOCK_GIT_ROOT is not set}/${2}"

exec git "${service}" "${repository}"
