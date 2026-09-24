<h2><img align="middle" src="https://raw.githubusercontent.com/odb/official-bash-logo/master/assets/Logos/Icons/PNG/64x64.png" >
Octojpack - Easy Joomla Extension Packaging
</h2>

Written by Llewellyn van der Merwe (@llewellynvdm)

With this script we can easily package multiple extensions in an automated way from a json configuration file, and environment variables.
It runs on your machine, on a server, or as a [GitHub Action](#github-action) that builds the package zip inside a workflow.

Linted by [#ShellCheck](https://github.com/koalaman/shellcheck)

> program only for ubuntu/debian and Gitea systems at this time (should you like to use it on other OS's please open and issue...)
---
# Install
```shell
$ sudo curl -L "https://raw.githubusercontent.com/octoleo/octojpack/refs/heads/master/src/octojpack" -o /usr/local/bin/octojpack
$ sudo chmod +x /usr/local/bin/octojpack
```
---
# Usage
> To see the help menu
```shell
$ octojpack -h
```
---
## Help Menu (octojpack)
```txt
Usage: octojpack [OPTION...]
	Options
	======================================================
   -p | --packager=<packager Name>
	Packager name
	example: octojpack -p="Vast Development Method"
	======================================================
   -pu | --packager-url=<//packager.url>
	Packager url
	example: octojpack -pu="https://git.vdm.dev/"
	======================================================
   -md | --main-dir=<path>
	load the main working directory
	example: octojpack --main-dir=/src
	======================================================
   -e | --env=<file>
	load the environment variables file
	example: octojpack --env=/src/.env
	======================================================
   --conf | --config=<path/url>
	load the configuration for the package in json format
	   file-example: src/example.json
	example: octojpack --config=config.json
	======================================================
   -ld | --licence-dir=<path>
	load the licence directory
	example: octojpack --licence-dir=/src/licence
	======================================================
   -t | --token=<access_token>
	load the global token
	example: octojpack --token=xxxxxxxxxxxxxxxxxxxxxxxxx
	======================================================
   -u | --url=<gitea>
	Global url of the Gitea instance
	example: octojpack --url="git.vdm.dev"
	======================================================
   -a | --api=<//gitea.api>
	Global api of the Gitea instance
	example: octojpack --api="https://git.vdm.dev/api/v1"
	======================================================
   --zip
	build a zip file of the package (Joomla installable package)
	   env: VDM_PACKAGE_ZIP=1
	example: octojpack --zip
	======================================================
   --zip-name=<file.zip>
	the file name of the package zip (default: <package_name>_<version>.zip)
	   env: VDM_PACKAGE_ZIP_NAME
	example: octojpack --zip-name=pkg_example_v1.0.0.zip
	======================================================
   --zip-dir=<path>
	the directory where the package zip is placed (default: <main-dir>/packages)
	   env: VDM_PACKAGE_ZIP_DIR
	example: octojpack --zip-dir=/src/packages
	======================================================
   --no-push
	do not push the package to the git repository
	   (the repository config section becomes optional)
	   env: VDM_PACKAGE_PUSH=0
	example: octojpack --no-push
	======================================================
   --keep-files
	keep the package build files once done (do not remove them)
	   env: VDM_KEEP_FILES=1
	example: octojpack --keep-files
	======================================================
   -o | --output=<file>
	write the build results (names, version, paths) to a file
	   in the GitHub Actions output format (defaults to $GITHUB_OUTPUT when set)
	   env: VDM_OUTPUT_FILE
	example: octojpack --output=/src/octojpack.out
	======================================================
   -q | --quiet
	mute all output messages
	example: octojpack --quiet
	======================================================
   --update
	to update your install
	example: octojpack --update
	======================================================
   --uninstall
	to uninstall this script
	example: octojpack --uninstall
	======================================================
   -h|--help
	display this help menu
	example: octojpack -h
	example: octojpack --help
	======================================================
			Octojpack v1.4.0
	======================================================
```

### Local Environment Variables File

Give the path to your .env file to the program like this:
```shell
$ octojpack --env="/home/username/.config/octojpack/custom.env"
```
Or with an environment variable you set before using the program like this:
```shell
$ export VDM_ENV_FILE_PATH="/home/username/.config/octojpack/custom.env"
```

> Default path is: /home/$USER/.config/octojpack/.env

### API ACCESS TOKEN (never share your token)

You can set your API access token for Gitea via the .env file like this:
```shell
VDM_GLOBAL_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxx"
```
Or you can pass the token directly to the script like this:
```shell
$ octojpack --token="xxxxxxxxxxxxxxxxxxxxxxxxx"
```
Or with an environment variable you set before using the program like this:
```shell
$ export VDM_GLOBAL_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Configuration File

To see the example of the json configuration options check out [src/example.json](https://git.vdm.dev/octoleo/octojpack/src/branch/master/src/example.json).

You can set your configuration file path via the .env file like this:
```shell
VDM_PACKAGE_CONF_FILE="/home/username/.config/octojpack/package_name_config.json"
```
Or you can pass it to the program by URL:
```shell
$ octojpack --conf="https://git.vdm.dev/api/v1/repos/octoleo/octojpack/raw/src/example.json"
```
Or via a local file path:
```shell
$ octojpack --conf="/home/username/.config/octojpack/package_name_config.json"
```
Or with an environment variable you set before using the program like this:
```shell
$ export VDM_PACKAGE_CONF_FILE="/home/username/.config/octojpack/package_name_config.json"
```

### Building a package zip (without pushing to git)

By default the program pushes the finished package to the Gitea repository named in the `repository` section of the configuration.
The switches below let it build the installable package zip instead (or as well), keep the build files, and report where everything is.
Each switch has a matching environment variable, so they can also be set from the .env file or a CI environment.

| Option | Environment variable | Default | Description |
| --- | --- | --- | --- |
| `--zip` | `VDM_PACKAGE_ZIP=1` | `0` | Build the package zip file. |
| `--zip-name=<file.zip>` | `VDM_PACKAGE_ZIP_NAME` | `<package_name>_<version>.zip` | File name of the package zip. |
| `--zip-dir=<path>` | `VDM_PACKAGE_ZIP_DIR` | `<main-dir>/packages` | Directory that receives the zip, its `.sha256` checksum and its `.json` manifest. |
| `--no-push` | `VDM_PACKAGE_PUSH=0` | `1` | Do not push to the git repository. The `repository` section of the configuration then becomes optional. |
| `--keep-files` | `VDM_KEEP_FILES=1` | `0` | Keep the package build directory (`<main-dir>/<repo>`) once done. |
| `-o` / `--output=<file>` | `VDM_OUTPUT_FILE` | `$GITHUB_OUTPUT` when set | Append the build results (names, version, paths, extensions) to a file in the GitHub Actions `key<<EOF` output format. |

```shell
$ octojpack --conf="/home/username/.config/octojpack/pkg_example.json" --zip --no-push --keep-files --output="/tmp/octojpack.out"
```

Next to the zip you get `<zip name>.sha256` (verify with `sha256sum -c`) and `<zip name>.json`, a manifest that lists the package details and every bundled extension:
```json
{
  "packager": "Octojpack v1.4.0",
  "created": "2026-09-24T10:00:00Z",
  "package": { "name": "Example Package", "package_name": "pkg_example", "code_name": "example", "version": "1.2.3", "tag": "v1.2.3", "min_joomla_version": "4.0", "max_joomla_version": "5.9" },
  "zip": { "name": "pkg_example_v1.2.3.zip", "sha256": "..." },
  "repository": { "owner": "tests", "repo": "pkg-example", "branch": "default", "url": "https://git.vdm.dev/tests/pkg-example", "pushed": false },
  "extensions": [
    { "owner": "tests", "repo": "com_example", "url": "https://git.vdm.dev/tests/com_example", "type": "component", "id": "com_example", "mode": "tags", "ref": "v1.2.3", "version": "v1.2.3", "message": "Release v1.2.3", "file": "src/tests__com_example__v1.2.3.zip" },
    { "owner": "tests", "repo": "plg_system_example", "url": "https://git.vdm.dev/tests/plg_system_example", "type": "plugin", "id": "example", "mode": "releases", "ref": "v2.0.0", "version": "v2.0.0", "message": "Release v2.0.0", "file": "src/tests__plg_system_example_v2.0.0.zip", "group": "system" }
  ]
}
```

---
# GitHub Action

The repository doubles as a composite GitHub Action (see [action.yml](action.yml)).
It installs nothing on your side: the action runs `src/octojpack` on the runner, passes every input through as the environment variable the script already understands, builds the package zip, uploads it as a workflow artifact and exposes the results as outputs so the next job (or the next workflow) can pick the package up.

## Quick start

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build the package
        id: package
        uses: octoleo/octojpack@master
        with:
          config: packages/pkg_example.json        # path in the repository, or a URL
          token: ${{ secrets.GITEA_TOKEN }}
          url: ${{ vars.GITEA_URL }}               # git.vdm.dev
          api: ${{ vars.GITEA_API }}               # https://git.vdm.dev/api/v1

      - run: echo "Built ${{ steps.package.outputs.package-zip-name }} (${{ steps.package.outputs.package-sha256 }})"
```

The action defaults differ from the command line on purpose, because a workflow usually wants the zip and not a git push:

| Behaviour | Command line default | Action default |
| --- | --- | --- |
| Build the package zip | off (`--zip`) | on (`zip: true`) |
| Push to the Gitea repository | on (`--no-push` to disable) | off (`push: true` to enable) |
| Keep the build directory | off (`--keep-files`) | on (`keep-files: true`) |
| Upload the zip as an artifact | n/a | on (`upload-artifact: true`) |

## Pushing to Gitea from a workflow (with octoleo/git-user)

When `push: true` the script clones/creates the package repository over SSH (`git@<url>:<owner>/<repo>.git`), commits, tags and pushes exactly like it does on the command line.
We use the [octoleo/git-user](https://github.com/octoleo/git-user) action right before this one to prepare everything that the push needs: the SSH key and known hosts for the Gitea host, the GPG signing key, and the git author identity.
Since git-user writes these to the global git configuration, this action needs no `git-*` inputs at all in that setup.

```yaml
      - name: Setup the git user
        uses: octoleo/git-user@v2
        with:
          gpg-key: ${{ secrets.GPG_KEY }}
          gpg-user: ${{ secrets.GPG_USER }}
          ssh-key: ${{ secrets.SSH_KEY }}
          ssh-pub: ${{ secrets.SSH_PUB }}
          git-user: ${{ secrets.GIT_USER }}
          git-email: ${{ secrets.GIT_EMAIL }}
          ssh-host: ${{ vars.GITEA_URL }}          # the Gitea host the package is pushed to

      - name: Build and push the package
        id: package
        uses: octoleo/octojpack@master
        with:
          config: packages/pkg_example.json
          token: ${{ secrets.GITEA_TOKEN }}
          url: ${{ vars.GITEA_URL }}
          api: ${{ vars.GITEA_API }}
          push: true
```

If you prefer to set git up yourself, the `git-author-name`, `git-author-email`, `git-signing-key`, `git-gpg-sign` and `git-ssh-key-path` inputs map to the `GIT_*` environment variables of the script.

## Passing the package to the next job

Every value the script knows about is an output, and the zip (with its `.sha256` and `.json` manifest) is uploaded as an artifact named after the zip file (`pkg_example_v1.2.3` for `pkg_example_v1.2.3.zip`), or after the `artifact-name` input.
Expose the outputs on the job and the next job can download the artifact by name:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: ${{ steps.package.outputs.artifact-name }}
      package-zip-name: ${{ steps.package.outputs.package-zip-name }}
      version: ${{ steps.package.outputs.version }}
      extensions: ${{ steps.package.outputs.extensions }}
    steps:
      - uses: actions/checkout@v4
      - id: package
        uses: octoleo/octojpack@master
        with:
          config: packages/pkg_example.json
          token: ${{ secrets.GITEA_TOKEN }}
          url: ${{ vars.GITEA_URL }}
          api: ${{ vars.GITEA_API }}

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: ${{ needs.build.outputs.artifact-name }}
          path: package
      - run: |
          cd package
          sha256sum -c "${ZIP%.zip}.sha256"
          jq -r '.[] | "\(.type) \(.id) \(.ref)"' <<<"${EXTENSIONS}"
        env:
          ZIP: ${{ needs.build.outputs.package-zip-name }}
          EXTENSIONS: ${{ needs.build.outputs.extensions }}
```

## Passing the package to the next workflow

A separate workflow can pick up the same artifact through a `workflow_run` trigger (or any workflow that knows the run id) with `actions/download-artifact` and the `run-id` and `github-token` inputs.
The manifest inside the artifact tells that workflow what it received (package name, version, checksum and the bundled extensions) without needing the outputs of the first workflow:

```yaml
name: Release
on:
  workflow_run:
    workflows: ["Package"]
    types: [completed]

jobs:
  release:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    permissions:
      actions: read
    steps:
      - uses: actions/download-artifact@v4
        with:
          pattern: pkg_*                            # or name: <artifact-name>
          path: package
          merge-multiple: true
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      - run: |
          cd package
          manifest=$(ls *.json | head -n1)
          echo "Package $(jq -r '.package.package_name' "$manifest") $(jq -r '.package.tag' "$manifest")"
          sha256sum -c *.sha256
```

## Inputs

All inputs are optional strings. An empty input leaves the matching environment variable unset, so the value from the configuration file (or the .env file) applies.

### Configuration

| Input | Environment variable | Description |
| --- | --- | --- |
| `config` | `VDM_PACKAGE_CONF_FILE` | Path (relative to the workspace) or URL of the JSON package configuration. |
| `config-json` | | Inline JSON configuration, used instead of `config` when set. |
| `env-file` | `VDM_ENV_FILE_PATH` | A .env file the script sources. |
| `main-dir` | `VDM_MAIN_DIR` | Working directory of the build. Default `$RUNNER_TEMP/octojpack`. |
| `licence-dir` | `VDM_LICENSE_DIR` | Directory holding the licence file. Default `<main-dir>/licenses`, then the workspace. |

### Gitea and packager

| Input | Environment variable | Description |
| --- | --- | --- |
| `token` | `VDM_GLOBAL_TOKEN` | Gitea API access token (use a secret). |
| `url` | `VDM_GLOBAL_URL` | Gitea host without protocol, for example `git.vdm.dev`. |
| `api` | `VDM_GLOBAL_API` | Gitea API base URL, for example `https://git.vdm.dev/api/v1`. |
| `packager` | `VDM_PACKAGER` | Packager name. |
| `packager-url` | `VDM_PACKAGER_URL` | Packager URL. |
| `packager-lang` | `VDM_PACKAGER_LANG` | Language tag used to resolve the package name (default `en-GB`). |

### Package overrides

These override the `package` section of the configuration.

| Input | Environment variable |
| --- | --- |
| `package-name` | `VDM_PACKAGE_NAME` |
| `code-name` | `VDM_CODE_NAME` |
| `name` | `VDM_NAME` |
| `description` | `VDM_DESCRIPTION` |
| `version-id` | `VDM_PACKAGE_VERSION_ID` |
| `version` | `VDM_PACKAGE_VERSION` (forces the version/tag, for example `v1.2.3`) |
| `min-joomla-version` | `VDM_MIN_JOOMLA_VERSION` |
| `max-joomla-version` | `VDM_MAX_JOOMLA_VERSION` |
| `copyright` | `VDM_COPYRIGHT` |
| `copyright-year` | `VDM_COPYRIGHT_YEAR` |
| `license` | `VDM_LICENSE` |
| `license-file` | `VDM_LICENSE_FILE` (file name inside `licence-dir`, or a URL) |
| `installation-file` | `VDM_INSTALLATION_FILE` (path relative to the workspace, or a URL) |
| `author` | `VDM_AUTHOR` |
| `author-email` | `VDM_AUTHOR_EMAIL` |
| `author-url` | `VDM_AUTHOR_URL` |
| `update-server` | `VDM_UPDATE_SERVER` |
| `changelog-server` | `VDM_CHANGELOG_SERVER` |

### Repository overrides

These override the `repository` section of the configuration (the Gitea repository the package is pushed to).

| Input | Environment variable |
| --- | --- |
| `repository-owner` | `VDM_PACKAGE_OWNER` |
| `repository-repo` | `VDM_PACKAGE_REPO` |
| `repository-branch` | `VDM_PACKAGE_REPO_BRANCH` |
| `repository-token-name` | `VDM_PACKAGE_TOKEN_NAME` |
| `repository-url-name` | `VDM_PACKAGE_URL_NAME` |
| `repository-api-name` | `VDM_PACKAGE_API_NAME` |

### Git (only used when `push` is true)

| Input | Environment variable |
| --- | --- |
| `git-author-name` | `GIT_AUTHOR_NAME` |
| `git-author-email` | `GIT_AUTHOR_EMAIL` |
| `git-signing-key` | `GIT_SIGNING_KEY` |
| `git-gpg-sign` | `GIT_GPG_SIGN` |
| `git-ssh-key-path` | `GIT_SSH_KEY_PATH` |

### Behaviour and artifact

| Input | Default | Description |
| --- | --- | --- |
| `zip` | `true` | Build the installable package zip. |
| `zip-name` | `<package_name>_<version>.zip` | File name of the zip. |
| `zip-dir` | `<main-dir>/packages` | Directory (relative to the workspace) that receives the zip, checksum and manifest. |
| `push` | `false` | Push the package to its Gitea repository. |
| `keep-files` | `true` | Keep the build directory so later steps can use `package-dir`. |
| `quiet` | `false` | Mute the script output. |
| `install-dependencies` | `true` | Install missing tools (git, curl, jq, unzip, zip, wget) with apt-get. |
| `summary` | `true` | Write the package details to the job summary. |
| `upload-artifact` | `true` | Upload the zip, checksum and manifest as an artifact. |
| `artifact-name` | zip file name without `.zip` | Name of the artifact. |
| `artifact-retention-days` | repository default | Days to keep the artifact. |
| `artifact-overwrite` | `true` | Replace an existing artifact with the same name (re-runs). |

### Custom token, url and api names

The configuration can point a file or the package repository at a differently named environment variable (`token_name`, `url_name`, `api_name`).
Such variables are simply set with `env:` on the step, since the action inherits the environment of the step that uses it:

```yaml
      - uses: octoleo/octojpack@master
        env:
          VDM_OTHER_TOKEN: ${{ secrets.OTHER_GITEA_TOKEN }}
          VDM_OTHER_API: https://other.gitea.host/api/v1
          VDM_OTHER_URL: other.gitea.host
        with:
          config: packages/pkg_example.json
          token: ${{ secrets.GITEA_TOKEN }}
          url: ${{ vars.GITEA_URL }}
          api: ${{ vars.GITEA_API }}
```

## Outputs

| Output | Description |
| --- | --- |
| `name` | Human readable package name (language constants are resolved). |
| `package-name` | Package name, for example `pkg_example`. |
| `code-name` | Package code name. |
| `version` | Version without the `v` prefix, for example `1.2.3`. |
| `tag` | Version as tagged, for example `v1.2.3`. |
| `package-dir` | Absolute path of the build directory (empty when `keep-files` is false). |
| `package-xml` | Absolute path of the package XML (empty when `keep-files` is false). |
| `package-zip` | Absolute path of the package zip (empty when `zip` is false). |
| `package-zip-name` | File name of the zip. |
| `package-zip-dir` | Directory holding the zip, checksum and manifest. |
| `package-sha256` | SHA-256 checksum of the zip. |
| `package-sha256-file` | Absolute path of the checksum file (`sha256sum -c` format). |
| `package-manifest` | Absolute path of the JSON manifest. |
| `repository-owner`, `repository-repo`, `repository-branch`, `repository-url` | The Gitea package repository (empty without a `repository` section). |
| `pushed` | `true` when the package was pushed to the Gitea repository. |
| `extensions` | JSON array of the bundled extensions (`owner`, `repo`, `url`, `type`, `id`, `mode`, `ref`, `version`, `message`, `file`, plus `group` or `client`). |
| `artifact-name` | Name of the uploaded artifact (for `actions/download-artifact`). |
| `artifact-id`, `artifact-url` | Id and URL of the uploaded artifact (empty when not uploaded). |

## Testing

[tests/run-local.sh](tests/run-local.sh) runs the script end-to-end against a small mock of the Gitea API ([tests/mock-gitea.py](tests/mock-gitea.py)), including a real git push into a local bare repository.
The [Test workflow](.github/workflows/test.yml) runs the same suite, lints the script with ShellCheck, exercises the action itself and hands the artifact to a second job.
The [Package workflow](.github/workflows/package.yml) is a ready to use example (run it manually) that chains `octoleo/git-user` and this action.

```shell
$ bash tests/run-local.sh
```

---
## Uninstall
```shell
$ octojpack --uninstall
```
---
# Free Software License
```txt
@copyright  Copyright (C) 2021 Llewellyn van der Merwe. All rights reserved.
@license    GNU General Public License version 2; see LICENSE
```
