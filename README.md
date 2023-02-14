# Octojpack - Easy Joomla Extension Packaging

With this script we can easily package multiple extensions in an automated way from a json configuration file, and environment variables.

> program only for ubuntu/debian and Gitea systems at this time (should you like to use it on other OS's please open and issue...)
---
# Install
```shell
$ sudo curl -L "https://git.vdm.dev/api/v1/repos/octoleo/octojpack/raw/src/octojpack" -o /usr/local/bin/octojpack
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
			Octojpack
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