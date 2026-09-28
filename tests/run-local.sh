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
# (the script builds its default paths from USER, so give it a user that has no home)
export HOME="${WORK}/home"
export USER="octojpack-tests"
mkdir -p "${HOME}"
LOG=""
unset VDM_ENV_FILE_PATH VDM_PACKAGE_CONF_FILE VDM_MAIN_DIR VDM_LICENSE_DIR GITHUB_OUTPUT VDM_OUTPUT_FILE
unset VDM_PACKAGE_ZIP VDM_PACKAGE_PUSH VDM_KEEP_FILES VDM_PACKAGE_ZIP_NAME VDM_PACKAGE_ZIP_DIR

cleanup() {
  if [ -n "${MOCK_PID}" ]; then
    kill "${MOCK_PID}" 2>/dev/null || true
  fi
  if [ -n "${KEEP_WORK:-}" ]; then
    echo "[info] work directory kept: ${WORK}"
  else
    rm -rf "${WORK}"
  fi
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  if [ -n "${LOG}" ] && [ -f "${LOG}" ]; then
    echo "--- last lines of ${LOG}:" >&2
    tail -n 40 "${LOG}" >&2
  fi
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

# the configs point at the mock on the port in use (the checked in files use 8765)
CONFIG="${WORK}/config.json"
CONFIG_NO_REPO="${WORK}/config-no-repository.json"
sed "s#127\.0\.0\.1:8765#127.0.0.1:${PORT}#g" "${HERE}/config.json" >"${CONFIG}"
sed "s#127\.0\.0\.1:8765#127.0.0.1:${PORT}#g" "${HERE}/config-no-repository.json" >"${CONFIG_NO_REPO}"

########################################################################
echo "== test 1: full config (tags, releases, branch), zip, no push, keep files, output file"
########################################################################
MAIN="${WORK}/t1"
OUT="${WORK}/t1.out"
LOG="${WORK}/t1.log"
mkdir -p "${MAIN}"
run_octojpack --conf="${CONFIG}" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
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
[ "$(output_value "${OUT}" repository-status)" = "disabled" ] || fail "repository-status output wrong"
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
assert_contains "$(cat "${LOG}")" 'failed to get tags from tests/missing_example' "explicitly optional missing repository is skipped"
assert_contains "$(cat "${LOG}")" '[Success] Package completely updated!' "success message"

########################################################################
echo "== test 2: no repository section, env switches, GITHUB_OUTPUT, files removed"
########################################################################
MAIN="${WORK}/t2"
OUT="${WORK}/t2.out"
LOG="${WORK}/t2.log"
mkdir -p "${MAIN}"
GITHUB_OUTPUT="${OUT}" VDM_PACKAGE_ZIP=true VDM_PACKAGE_PUSH=false VDM_KEEP_FILES=no \
  run_octojpack --conf="${CONFIG_NO_REPO}" --main-dir="${MAIN}" --url="gitea.test" >"${LOG}" 2>&1 ||
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
jq -e '.repository.owner == "" and .repository.pushed == false and .repository.status == "disabled" and (.extensions | length == 1)' "$(output_value "${OUT}" package-manifest)" >/dev/null || fail "manifest wrong"
if [ -f "${MAIN}/files.json" ] || [ -f "${MAIN}/.octojpack_files.json" ]; then
  fail "scratch files should be removed"
fi
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
if run_octojpack --conf="${CONFIG_NO_REPO}" --main-dir="${MAIN}" --url="gitea.test" >"${LOG}" 2>&1; then
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
  run_octojpack --conf="${CONFIG}" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --zip --keep-files --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 6 script failed: $(cat "${LOG}")"
pass "test 6 script exit code"
[ "$(output_value "${OUT}" pushed)" = "true" ] || fail "pushed output should be true"
[ "$(output_value "${OUT}" repository-status)" = "pushed" ] || fail "repository-status should be pushed"
jq -e '.repository.pushed == true and .repository.status == "pushed"' "$(output_value "${OUT}" package-manifest)" >/dev/null || fail "manifest push status wrong"
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
  run_octojpack --conf="${CONFIG}" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 7 script failed: $(cat "${LOG}")"
assert_contains "$(cat "${LOG}")" 'No changes found in (tests/pkg-example) repository' "no changes detected"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "1" ] || fail "remote should still have 1 commit"
[ "$(output_value "${OUT}" pushed)" = "false" ] || fail "pushed output should be false when nothing changed"
[ "$(output_value "${OUT}" repository-status)" = "unchanged" ] || fail "repository-status should be unchanged"
[ -z "$(output_value "${OUT}" package-zip)" ] || fail "no zip expected without --zip"
[ ! -d "${MAIN}/pkg-example" ] || fail "package dir should be removed without --keep-files"
pass "legacy behaviour (no zip, files removed) still works"

########################################################################
echo "== test 8: update an existing repository with changes (new commit and tag pushed)"
########################################################################
MAIN="${WORK}/t8"
OUT="${WORK}/t8.out"
LOG="${WORK}/t8.log"
CONFIG_NEXT="${WORK}/config-next.json"
mkdir -p "${MAIN}"
# the component now comes from a repository that carries a newer tag (v1.3.0 in the mock)
jq '(.files[] | select(.repo == "com_example") | .repo) |= "com_example-next"' "${CONFIG}" >"${CONFIG_NEXT}"
# Reject the new tag first: an atomic push must leave the branch unchanged.
cat >"${REMOTE}/tests/pkg-example.git/hooks/update" <<'HOOK'
#!/bin/bash
[[ "${1}" != refs/tags/v1.3.0 ]]
HOOK
chmod +x "${REMOTE}/tests/pkg-example.git/hooks/update"
if GIT_SSH_COMMAND="${HERE}/fake-ssh.sh" MOCK_GIT_ROOT="${REMOTE}" \
  GIT_AUTHOR_NAME="Octojpack Tests" GIT_AUTHOR_EMAIL="tests@example.org" GIT_GPG_SIGN=false \
  run_octojpack --conf="${CONFIG_NEXT}" --main-dir="${WORK}/t8-rejected" --licence-dir="${HERE}/licenses" \
    --url="gitea.test" >"${LOG}" 2>&1; then
  fail "a rejected package tag must fail publication"
fi
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "1" ] || fail "rejected tag partially advanced the branch"
if git -C "${REMOTE}/tests/pkg-example.git" show-ref --verify --quiet refs/tags/v1.3.0; then
  fail "rejected tag was published"
fi
rm "${REMOTE}/tests/pkg-example.git/hooks/update"
pass "tag rejection publishes neither branch nor tag"

GIT_SSH_COMMAND="${HERE}/fake-ssh.sh" MOCK_GIT_ROOT="${REMOTE}" \
  GIT_AUTHOR_NAME="Octojpack Tests" GIT_AUTHOR_EMAIL="tests@example.org" GIT_GPG_SIGN=false \
  run_octojpack --conf="${CONFIG_NEXT}" --main-dir="${MAIN}" --licence-dir="${HERE}/licenses" \
  --url="gitea.test" --zip --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "test 8 script failed"
pass "test 8 script exit code"
[ "$(output_value "${OUT}" tag)" = "v1.3.0" ] || fail "tag output should be v1.3.0"
[ "$(output_value "${OUT}" pushed)" = "true" ] || fail "pushed output should be true"
[ "$(output_value "${OUT}" repository-status)" = "pushed" ] || fail "repository-status should be pushed"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "2" ] || fail "remote should have 2 commits"
git -C "${REMOTE}/tests/pkg-example.git" show-ref --tags --quiet "refs/tags/v1.3.0" || fail "remote should have the v1.3.0 tag"
assert_contains "$(git -C "${REMOTE}/tests/pkg-example.git" ls-tree -r --name-only master)" 'src/tests__com_example-next__v1.3.0.zip' "remote tree updated"
[ -f "${MAIN}/packages/pkg_example_v1.3.0.zip" ] || fail "zip for the new version not found"
pass "existing repository updated with a new commit and tag"

# Simulate an older non-atomic run that published the branch but lost its tag.
git -C "${REMOTE}/tests/pkg-example.git" update-ref -d refs/tags/v1.3.0
GIT_SSH_COMMAND="${HERE}/fake-ssh.sh" MOCK_GIT_ROOT="${REMOTE}" \
  GIT_AUTHOR_NAME="Octojpack Tests" GIT_AUTHOR_EMAIL="tests@example.org" GIT_GPG_SIGN=false \
  run_octojpack --conf="${CONFIG_NEXT}" --main-dir="${WORK}/t8-retry" --licence-dir="${HERE}/licenses" \
    --url="gitea.test" --output="${WORK}/t8-retry.out" >"${LOG}" 2>&1 || fail "missing tag retry failed"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-list --count master)" = "2" ] || fail "tag retry should not create a commit"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-parse refs/tags/v1.3.0)" = "$(git -C "${REMOTE}/tests/pkg-example.git" rev-parse master)" ] || fail "missing tag was not restored"
[ "$(output_value "${WORK}/t8-retry.out" repository-status)" = pushed ] || fail "tag recovery should report a push"
[ "$(git -C "${REMOTE}/tests/pkg-example.git" rev-parse refs/tags/v1.2.3)" = "$(git -C "${REMOTE}/tests/pkg-example.git" rev-parse master^)" ] || fail "existing release tag was moved"
pass "unchanged package recovers an absent release tag without moving existing tags"

########################################################################
echo "== test 9: hardening (cli precedence, relative paths, no env leaks, safe names)"
########################################################################
MAIN="${WORK}/t9"
OUT="${WORK}/t9.out"
LOG="${WORK}/t9.log"
CONFIG_HARD="${WORK}/config-hardening.json"
ENV_FILE="${WORK}/t9.env"
mkdir -p "${MAIN}/cwd"
# a name that matches an environment variable must not resolve to it, and
# a package name with path separators must stay inside the main directory
jq 'del(.repository) | .package.name = "VDM_GLOBAL_TOKEN" | .package.description = "HOME" | .package.package_name = "../../pkg_escape"' "${CONFIG_NO_REPO}" >"${CONFIG_HARD}"
# the env file tries to force a push and a different zip name, the command line must win
printf 'VDM_PACKAGE_PUSH=1\nVDM_PACKAGE_ZIP_NAME="from-env.zip"\n' >"${ENV_FILE}"
(cd "${MAIN}/cwd" && VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="${API}" bash "${SCRIPT}" --env="${ENV_FILE}" \
  --conf="${CONFIG_HARD}" --main-dir="${MAIN}" --url="gitea.test" --zip --zip-name="from-cli.zip" --zip-dir="dist" \
  --no-push --output="results.out" >"${LOG}" 2>&1) || fail "test 9 script failed"
pass "test 9 script exit code"
OUT="${MAIN}/cwd/results.out"
[ -f "${OUT}" ] || fail "relative --output should be written relative to the start directory"
[ -f "${MAIN}/cwd/dist/from-cli.zip" ] || fail "relative --zip-dir should be resolved against the start directory (and --zip-name must win over the env file)"
pass "relative --output and --zip-dir resolve against the start directory"
[ "$(output_value "${OUT}" repository-status)" = "disabled" ] || fail "--no-push must win over VDM_PACKAGE_PUSH=1 from the env file"
pass "command line options take precedence over the env file"
[ "$(output_value "${OUT}" name)" = "VDM_GLOBAL_TOKEN" ] || fail "a name must never resolve to an environment variable (got: $(output_value "${OUT}" name))"
assert_contains "$(unzip -p "${MAIN}/cwd/dist/from-cli.zip" README.md)" '# VDM_GLOBAL_TOKEN' "readme name is the literal config value"
assert_contains "$(unzip -p "${MAIN}/cwd/dist/from-cli.zip" README.md)" 'HOME' "readme description is the literal config value"
! unzip -p "${MAIN}/cwd/dist/from-cli.zip" README.md | grep -q 'test-token' || fail "the token leaked into the README"
pass "config values never resolve to environment variables"
# ../../pkg_escape relative to the main dir would land next to the work dir
if [ -e "${WORK}/pkg_escape" ] || [ -e "$(dirname "${WORK}")/pkg_escape" ]; then
  fail "package folder escaped the main directory"
fi
[ -d "${MAIN}" ] || fail "main dir must never be removed"
pass "package folder name is kept inside the main directory"

########################################################################
echo "== test 10: GitHub tags and explicit refs use source archives without release assets"
########################################################################
CONFIG_GITHUB="${WORK}/config-github.json"
jq '.package.version_id = "com_example" | .files = [{owner: "tests", repo: "com_github", id: "com_example", type: "component", mode: "tags"}]' \
  "${CONFIG_NO_REPO}" >"${CONFIG_GITHUB}"
MAIN="${WORK}/t10"
OUT="${WORK}/t10.out"
LOG="${WORK}/t10.log"
VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="http://127.0.0.1:${PORT}/github" \
  bash "${SCRIPT}" --env=/dev/null --conf="${CONFIG_GITHUB}" --main-dir="${MAIN}" \
  --url=github.com --zip --no-push --keep-files --output="${OUT}" >"${LOG}" 2>&1 ||
  fail "GitHub tags build failed"
[ "$(output_value "${OUT}" tag)" = "v1.2.3" ] || fail "GitHub tag was not resolved"
output_value "${OUT}" extensions | jq -e '.[0].message == "Release v1.2.3"' >/dev/null || fail "GitHub tag message fallback missing"
unzip -tq "$(output_value "${OUT}" package-dir)/src/tests__com_github__v1.2.3.zip" >/dev/null || fail "GitHub tag ZIP invalid"
pass "GitHub tags work without a message field or uploaded release assets"

for mode in v7.8.9 branch:main branch:feature/topic release/v7.8.9; do
  CASE_NAME="${mode//[:\/]/_}"
  MAIN="${WORK}/t10-${CASE_NAME}"
  OUT="${WORK}/t10-${CASE_NAME}.out"
  LOG="${WORK}/t10-${CASE_NAME}.log"
  jq --arg mode "${mode}" '.files[0].repo = "first_tag" | .files[0].mode = $mode' \
    "${CONFIG_GITHUB}" >"${WORK}/config-ref.json"
  VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="http://127.0.0.1:${PORT}/github" \
    bash "${SCRIPT}" --env=/dev/null --conf="${WORK}/config-ref.json" --main-dir="${MAIN}" \
    --url=github.com --zip --no-push --output="${OUT}" >"${LOG}" 2>&1 ||
    fail "GitHub explicit ref ${mode} failed"
  output_value "${OUT}" extensions | jq -e --arg ref "${mode#branch:}" '.[0].ref == $ref' >/dev/null ||
    fail "explicit ref ${mode} was not retained"
done
pass "explicit tags and branches, including slash refs, retain their names without a tag listing"

for failure in missing invalid_archive; do
  MAIN="${WORK}/t10-${failure}"
  LOG="${WORK}/t10-${failure}.log"
  if [ "${failure}" = 'missing' ]; then
    jq '.files[0].mode = "missing"' "${CONFIG_GITHUB}" >"${WORK}/config-invalid.json"
  else
    jq '.files[0].repo = "invalid_archive"' "${CONFIG_GITHUB}" >"${WORK}/config-invalid.json"
  fi
  if VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="http://127.0.0.1:${PORT}/github" \
    bash "${SCRIPT}" --env=/dev/null --conf="${WORK}/config-invalid.json" --main-dir="${MAIN}" \
      --url=github.com --zip --no-push >"${LOG}" 2>&1; then
    fail "${failure} must not create a package with an invalid extension ZIP"
  fi
  [ ! -d "${MAIN}/packages" ] || fail "${failure} produced package output"
done
pass "missing tags and non-ZIP archive responses fail without creating a package"

MAIN="${WORK}/t10-partial"
LOG="${WORK}/t10-partial.log"
jq '.files += [{owner: "tests", repo: "invalid_archive", id: "required_plugin", type: "plugin", group: "console", mode: "v1.2.3"}]' \
  "${CONFIG_GITHUB}" >"${WORK}/config-partial.json"
if VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="http://127.0.0.1:${PORT}/github" \
  bash "${SCRIPT}" --env=/dev/null --conf="${WORK}/config-partial.json" --main-dir="${MAIN}" \
    --url=github.com --zip --no-push >"${LOG}" 2>&1; then
  fail "a valid component plus a failed required plugin must not publish a partial package"
fi
[ ! -d "${MAIN}/packages" ] || fail "partial package output was created"
assert_contains "$(cat "${LOG}")" 'Required extension tests/invalid_archive could not be loaded' "required source failure stops the entire package"

for invalid_owner in '' 'invalid owner'; do
  MAIN="${WORK}/t10-invalid-owner"
  LOG="${WORK}/t10-invalid-owner.log"
  jq --arg owner "${invalid_owner}" '.files += [{owner: $owner, repo: "required_plugin", id: "required_plugin", type: "plugin", group: "console", mode: "v1.2.3"}]' \
    "${CONFIG_GITHUB}" >"${WORK}/config-invalid-owner.json"
  if VDM_GLOBAL_TOKEN="test-token" VDM_GLOBAL_API="http://127.0.0.1:${PORT}/github" \
    bash "${SCRIPT}" --env=/dev/null --conf="${WORK}/config-invalid-owner.json" --main-dir="${MAIN}" \
      --url=github.com --zip --no-push >"${LOG}" 2>&1; then
    fail "required extension with empty/invalid owner must not be dropped from the package"
  fi
  [ ! -d "${MAIN}/packages" ] || fail "invalid owner produced a partial package"
done
pass "every configured entry is validated, including empty or whitespace-containing owners"

########################################################################
echo "== test 11: configured update and changelog URLs round-trip through valid XML"
########################################################################
MAIN="${WORK}/t11"
LOG="${WORK}/t11.log"
OUT="${WORK}/t11.out"
UPDATE_URL='https://example.org/update.xml?extension=pkg_example&channel=stable&label="release"'
CHANGELOG_URL="https://example.org/changelog.xml?extension=pkg_example&channel=stable&label='release'"
VDM_UPDATE_SERVER="${UPDATE_URL}" VDM_CHANGELOG_SERVER="${CHANGELOG_URL}" \
  run_octojpack --conf="${CONFIG_NO_REPO}" --main-dir="${MAIN}" --url="gitea.test" \
    --zip --no-push --keep-files --output="${OUT}" >"${LOG}" 2>&1 || fail "URL XML build failed"
python3 - "$(output_value "${OUT}" package-xml)" "${UPDATE_URL}" "${CHANGELOG_URL}" <<'PY' || fail "URL values did not round-trip through XML"
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
assert root.findtext("updateservers/server") == sys.argv[2]
assert root.findtext("changelogurl") == sys.argv[3]
PY
pass "update and changelog URLs preserve their values in parseable package XML"

echo
echo "All tests passed."
