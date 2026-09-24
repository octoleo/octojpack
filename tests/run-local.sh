#!/bin/bash
# End-to-end tests of the octojpack script against the mock Gitea API.
#
#   bash tests/run-local.sh
#
# The mock API (tests/mock-gitea.py) is started automatically unless one is
# already listening on the port (MOCK_GITEA_PORT, default 8765).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
SCRIPT="${ROOT}/src/octojpack"
PORT="${MOCK_GITEA_PORT:-8765}"
API="http://127.0.0.1:${PORT}/api/v1"
WORK="$(mktemp -d)"
MOCK_PID=""

# keep the script away from any real user configuration
export HOME="${WORK}/home"
mkdir -p "${HOME}"
unset VDM_ENV_FILE_PATH VDM_PACKAGE_CONF_FILE VDM_MAIN_DIR VDM_LICENSE_DIR GITHUB_OUTPUT VDM_OUTPUT_FILE
unset VDM_PACKAGE_ZIP VDM_PACKAGE_PUSH VDM_KEEP_FILES VDM_PACKAGE_ZIP_NAME VDM_PACKAGE_ZIP_DIR

cleanup() {
  if [ -n "${MOCK_PID}" ]; then
    kill "${MOCK_PID}" 2>/dev/null || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[PASS] $*"
}

# print the value of one key from a GitHub Actions output file
output_value() {
  awk -v key="${2}" '
    index($0, key "<<") == 1 { delimiter = substr($0, length(key) + 3); reading = 1; next }
    reading && $0 == delimiter { reading = 0; next }
    reading { print }
  ' "${1}"
}

# assert that a file (or a command output) contains a string
assert_contains() {
  local haystack="${1}"
  local needle="${2}"
  local label="${3}"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    pass "${label}"
  else
    fail "${label} (missing: ${needle})"
  fi
}

# common script options
run_octojpack() {
  VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="${API}" bash "${SCRIPT}" --env=/dev/null "$@"
}

########################################################################
# start the mock Gitea API
########################################################################
if ! curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
  python3 "${HERE}/mock-gitea.py" --port "${PORT}" >"${WORK}/mock-gitea.log" 2>&1 &
  MOCK_PID=$!
  for _ in $(seq 1 50); do
    curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 && break
    sleep 0.2
  done
  curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 || fail "the mock Gitea API did not start"
fi
pass "mock Gitea API is running on port ${PORT}"

########################################################################
echo "== test 1: full config (tags, releases, branch), zip, no push, keep files, output file"
########################################################################
MAIN="${WORK}/t1"
OUT="${WORK}/t1.out"
LOG="${WORK}/t1.log"
mkdir -p "${MAIN}"
run_octojpack --conf="${HERE}/config.json" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --zip --no-push --keep-files --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 1 script failed: $(cat "${LOG}")"
pass "test 1 script exit code"

ZIP="$(output_value "${OUT}" package-zip)"
[ -f "${ZIP}" ] || fail "package zip not found (${ZIP})"
pass "package zip exists (${ZIP})"
[ "$(basename "${ZIP}")" = "pkg_example_v1.2.3.zip" ] || fail "unexpected zip name: $(basename "${ZIP}")"
pass "package zip name uses <package_name>_<tag>.zip"

LISTING="$(unzip -Z1 "${ZIP}")"
for entry in pkg_example.xml README.md LICENSE install_example.php \
  src/tests__com_example__v1.2.3.zip src/tests__plg_system_example_v2.0.0.zip src/tests__mod_example__master.zip \
  languages/en-GB/en-GB.pkg_example.sys.ini languages/en-GB/en-GB.pkg_example.ini; do
  assert_contains "${LISTING}" "${entry}" "zip contains ${entry}"
done

SHA_FILE="$(output_value "${OUT}" package-sha256-file)"
[ -f "${SHA_FILE}" ] || fail "sha256 file not found (${SHA_FILE})"
(cd "$(dirname "${ZIP}")" && sha256sum -c --quiet "${SHA_FILE}") || fail "sha256 file does not verify"
pass "sha256 file verifies"
[ "$(output_value "${OUT}" package-sha256)" = "$(sha256sum "${ZIP}" | awk '{print $1}')" ] || fail "sha256 output mismatch"
pass "sha256 output matches"

MANIFEST="$(output_value "${OUT}" package-manifest)"
[ -f "${MANIFEST}" ] || fail "manifest not found (${MANIFEST})"
jq -e '.extensions | length == 3' "${MANIFEST}" >/dev/null || fail "manifest should list 3 extensions: $(cat "${MANIFEST}")"
jq -e '.package.name == "Example Package" and .package.tag == "v1.2.3" and .package.version == "1.2.3"' "${MANIFEST}" >/dev/null || fail "manifest package details wrong: $(cat "${MANIFEST}")"
jq -e '.repository.owner == "tests" and .repository.repo == "pkg-example" and .repository.pushed == false' "${MANIFEST}" >/dev/null || fail "manifest repository details wrong: $(cat "${MANIFEST}")"
jq -e '.zip.name == "pkg_example_v1.2.3.zip" and (.zip.sha256 | length == 64)' "${MANIFEST}" >/dev/null || fail "manifest zip details wrong"
jq -e '.extensions[] | select(.repo == "com_example") | .mode == "tags" and .ref == "v1.2.3" and .version == "v1.2.3" and .file == "src/tests__com_example__v1.2.3.zip"' "${MANIFEST}" >/dev/null || fail "manifest component entry wrong"
jq -e '.extensions[] | select(.repo == "plg_system_example") | .mode == "releases" and .ref == "v2.0.0" and .group == "system" and .file == "src/tests__plg_system_example_v2.0.0.zip"' "${MANIFEST}" >/dev/null || fail "manifest plugin entry wrong"
jq -e '.extensions[] | select(.repo == "mod_example") | .mode == "branch" and .ref == "master" and .version == "v3.0.0" and .client == "site"' "${MANIFEST}" >/dev/null || fail "manifest module entry wrong"
pass "manifest content"

[ "$(output_value "${OUT}" name)" = "Example Package" ] || fail "name output wrong"
[ "$(output_value "${OUT}" package-name)" = "pkg_example" ] || fail "package-name output wrong"
[ "$(output_value "${OUT}" code-name)" = "example" ] || fail "code-name output wrong"
[ "$(output_value "${OUT}" version)" = "1.2.3" ] || fail "version output wrong"
[ "$(output_value "${OUT}" tag)" = "v1.2.3" ] || fail "tag output wrong"
[ "$(output_value "${OUT}" pushed)" = "false" ] || fail "pushed output wrong"
[ "$(output_value "${OUT}" repository-url)" = "https://gitea.test/tests/pkg-example" ] || fail "repository-url output wrong"
[ "$(output_value "${OUT}" package-zip-name)" = "pkg_example_v1.2.3.zip" ] || fail "package-zip-name output wrong"
[ "$(output_value "${OUT}" package-zip-dir)" = "${MAIN}/packages" ] || fail "package-zip-dir output wrong"
output_value "${OUT}" extensions | jq -e 'length == 3' >/dev/null || fail "extensions output wrong"
pass "outputs content"

PKG_DIR="$(output_value "${OUT}" package-dir)"
PKG_XML="$(output_value "${OUT}" package-xml)"
[ -d "${PKG_DIR}" ] || fail "package dir was not kept (${PKG_DIR})"
[ -f "${PKG_XML}" ] || fail "package xml not found (${PKG_XML})"
pass "package files kept"

XML="$(cat "${PKG_XML}")"
assert_contains "${XML}" '<version>1.2.3</version>' "xml version"
assert_contains "${XML}" '<file type="component" id="com_example">tests__com_example__v1.2.3.zip</file>' "xml component file"
assert_contains "${XML}" '<file type="plugin" id="example" group="system">tests__plg_system_example_v2.0.0.zip</file>' "xml plugin file"
assert_contains "${XML}" '<file type="module" id="mod_example" client="site">tests__mod_example__master.zip</file>' "xml module file"
assert_contains "${XML}" '<scriptfile>install_example.php</scriptfile>' "xml script file"
assert_contains "${XML}" '<changelogurl>https://example.org/changelog/pkg_example_changelog.xml</changelogurl>' "xml changelog"
assert_contains "${XML}" '<language tag="en-GB">en-GB/en-GB.pkg_example.sys.ini</language>' "xml language"
assert_contains "$(cat "${PKG_DIR}/README.md")" '# Example Package (v1.2.3)' "readme title"
assert_contains "$(cat "${LOG}")" 'failed to get tags from tests/missing_example' "missing repository is skipped, not fatal"
assert_contains "$(cat "${LOG}")" '[Success] Package completely updated!' "success message"

########################################################################
echo "== test 2: no repository section, env switches, GITHUB_OUTPUT, files removed"
########################################################################
MAIN="${WORK}/t2"
OUT="${WORK}/t2.out"
LOG="${WORK}/t2.log"
mkdir -p "${MAIN}"
GITHUB_OUTPUT="${OUT}" VDM_PACKAGE_ZIP=true VDM_PACKAGE_PUSH=false VDM_KEEP_FILES=no \
  run_octojpack --conf="${HERE}/config-no-repository.json" --main-dir="${MAIN}" --url="gitea.test" >"${LOG}" 2>&1 ||
  fail "test 2 script failed: $(cat "${LOG}")"
pass "test 2 script exit code"
ZIP="$(output_value "${OUT}" package-zip)"
[ "${ZIP}" = "${MAIN}/packages/pkg_minimal_1.0.0.zip" ] || fail "unexpected zip path: ${ZIP}"
[ -f "${ZIP}" ] || fail "package zip not found (${ZIP})"
pass "zip built without a repository section (${ZIP})"
[ -z "$(output_value "${OUT}" package-dir)" ] || fail "package-dir should be empty when files are removed"
[ ! -d "${MAIN}/pkg_minimal" ] || fail "package dir should have been removed"
[ -d "${MAIN}" ] || fail "main dir must never be removed"
pass "build files removed, main dir kept"
[ -z "$(output_value "${OUT}" repository-url)" ] || fail "repository-url should be empty"
[ "$(output_value "${OUT}" name)" = "Minimal Package" ] || fail "name output wrong"
jq -e '.repository.owner == "" and .repository.pushed == false and (.extensions | length == 1)' "$(output_value "${OUT}" package-manifest)" >/dev/null || fail "manifest wrong"
assert_contains "$(unzip -Z1 "${ZIP}")" 'LICENSE' "licence from URL"
pass "test 2 outputs"

########################################################################
echo "== test 3: config by URL, custom zip name and directory"
########################################################################
MAIN="${WORK}/t3"
OUT="${WORK}/t3.out"
LOG="${WORK}/t3.log"
mkdir -p "${MAIN}"
run_octojpack --conf="http://127.0.0.1:${PORT}/config.json" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --zip --zip-name="custom-package" --zip-dir="${WORK}/dist" --no-push --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 3 script failed: $(cat "${LOG}")"
[ -f "${WORK}/dist/custom-package.zip" ] || fail "custom zip not found"
[ -f "${WORK}/dist/custom-package.json" ] || fail "custom manifest not found"
[ -f "${WORK}/dist/custom-package.sha256" ] || fail "custom sha256 not found"
[ "$(output_value "${OUT}" package-zip)" = "${WORK}/dist/custom-package.zip" ] || fail "package-zip output wrong"
pass "config by URL with custom zip name and directory"

########################################################################
echo "== test 4: push enabled (default) without repository details must fail"
########################################################################
MAIN="${WORK}/t4"
LOG="${WORK}/t4.log"
mkdir -p "${MAIN}"
if run_octojpack --conf="${HERE}/config-no-repository.json" --main-dir="${MAIN}" --url="gitea.test" >"${LOG}" 2>&1; then
  fail "test 4 should have failed"
fi
assert_contains "$(cat "${LOG}")" 'correct destination repository details' "missing repository details error"

########################################################################
echo "== test 5: help menu"
########################################################################
HELP="$(bash "${SCRIPT}" --help)"
for option in '--zip' '--zip-name' '--zip-dir' '--no-push' '--keep-files' '--output'; do
  assert_contains "${HELP}" "${option}" "help lists ${option}"
done

########################################################################
echo "== test 6: push to a (local bare) git repository over the fake ssh, keep files"
########################################################################
MAIN="${WORK}/t6"
OUT="${WORK}/t6.out"
LOG="${WORK}/t6.log"
REMOTE="${WORK}/remote"
mkdir -p "${MAIN}" "${REMOTE}/tests"
git init --bare --quiet --initial-branch=master "${REMOTE}/tests/pkg-example.git"
chmod +x "${HERE}/fake-ssh.sh"
GIT_SSH_COMMAND="${HERE}/fake-ssh.sh" MOCK_GIT_ROOT="${REMOTE}" \
  GIT_AUTHOR_NAME="Octojpack Tests" GIT_AUTHOR_EMAIL="tests@example.org" GIT_GPG_SIGN=false \
  run_octojpack --conf="${HERE}/config.json" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --zip --keep-files --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 6 script failed: $(cat "${LOG}")"
pass "test 6 script exit code"
[ "$(output_value "${OUT}" pushed)" = "true" ] || fail "pushed output should be true"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "1" ] || fail "remote should have 1 commit"
git -C "${REMOTE}/tests/pkg-example.git" show-ref --tags --quiet "refs/tags/v1.2.3" || fail "remote should have the v1.2.3 tag"
TREE="$(git -C "${REMOTE}/tests/pkg-example.git" ls-tree -r --name-only master)"
for entry in pkg_example.xml README.md LICENSE install_example.php src/tests__com_example__v1.2.3.zip languages/en-GB/en-GB.pkg_example.ini; do
  assert_contains "${TREE}" "${entry}" "remote tree contains ${entry}"
done
PKG_DIR="$(output_value "${OUT}" package-dir)"
[ -f "${PKG_DIR}/pkg_example.xml" ] || fail "package files should be kept (copied) when pushing"
pass "package files kept while pushing"
[ -f "$(output_value "${OUT}" package-zip)" ] || fail "zip should exist when pushing"
pass "zip built while pushing"

########################################################################
echo "== test 7: second push run finds no changes (existing repository path)"
########################################################################
MAIN="${WORK}/t7"
OUT="${WORK}/t7.out"
LOG="${WORK}/t7.log"
mkdir -p "${MAIN}"
GIT_SSH_COMMAND="${HERE}/fake-ssh.sh" MOCK_GIT_ROOT="${REMOTE}" \
  GIT_AUTHOR_NAME="Octojpack Tests" GIT_AUTHOR_EMAIL="tests@example.org" GIT_GPG_SIGN=false \
  run_octojpack --conf="${HERE}/config.json" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 7 script failed: $(cat "${LOG}")"
assert_contains "$(cat "${LOG}")" 'No changes found in (tests/pkg-example) repository' "no changes detected"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "1" ] || fail "remote should still have 1 commit"
[ -z "$(output_value "${OUT}" package-zip)" ] || fail "no zip expected without --zip"
[ ! -d "${MAIN}/pkg-example" ] || fail "package dir should be removed without --keep-files"
pass "legacy behaviour (no zip, files removed) still works"

echo
echo "All tests passed."
