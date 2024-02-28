# Tesseract Orange（IN DEVELOPMENT）

Provides reproducible Tesseract build optimized for your machine.

<https://gitlab.com/tesseract-prebuilt/tesseract-orange>  
[![The GitLab CI pipeline status badge of the project's `main` branch](https://gitlab.com/tesseract-prebuilt/tesseract-orange/badges/main/pipeline.svg?ignore_skipped=true "Click here to check out the comprehensive status of the GitLab CI pipelines")](https://gitlab.com/tesseract-prebuilt/tesseract-orange/-/pipelines) [![GitHub Actions workflow status badge](https://github.com/tesseract-prebuilt/tesseract-orange/actions/workflows/check-potential-problems.yml/badge.svg "GitHub Actions workflow status")](https://github.com/tesseract-prebuilt/tesseract-orange/actions/workflows/check-potential-problems.yml) [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/github.com/tesseract-prebuilt/tesseract-orange "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/github.com/tesseract-prebuilt/tesseract-orange)

This project features programs that will download, and build a Tesseract OCR software that is highly-optimized to your host machine.

## Features

Here are some prominent features of this product that worth noticing:

* The build is run in a Docker container, thus will not pollute your host system
* No files will be installed in the standard system paths, thus your runtime environment will also not be polluted, the installation can be easily cleaned up when not used
* The built software is packaged in a highly-compressed tar archive, bundled with installer program to make ease of (re-)installation

## Prerequisites

This section documents some prerequisites of the usage of this product:

### Build host

This section documents the prerequisites of the host machine that runs [the build environment](#builder-container) of the product (which should also be the one that runs the built product):

* Docker Engine (or equivalent counterparts) software installation  
  For running the container for running the product build program(A.K.A. [the "Builder container"](#builder-container)).  A recent version of the software should suffice.
* A recent version of the Docker Compose container orchestration utility(or its equivalent counterparts).  A recent version that supports [version 3 of the Compose file specification](https://docs.docker.com/compose/compose-file/) should suffice.

### Builder container

This section documents the prerequisites of the product building container:

* GNU Bash  
  The runtime interpreter of the build program.  **Requires version >= 4.3**(name reference variable support to be specific).
* A supported operating system image that is the same/compatible with the builder host's system, currently supporting Ubuntu 22.04/23.10.  This product is designed with cross-platform compatibility in mind thus it may be possible to port it to other Linux distributions as well, patches welcome!

## Environment variables that can change the prodoct builder's behaviors

### APT_SWITCH_LOCAL_MIRROR

Whether to enable the functionality to automatically switching to a local APT software management system software mirror.

#### Accepted values

* `false`: Disable functionality
* `true`: Enable functionality

#### Default value

`true`

### LEPTONICA_VERSION

Determine [which version of Leptonica](https://github.com/DanBloomberg/leptonica/releases) to build.

#### Accepted values

A Leptonica version number that is available from [the Git repository tags](https://github.com/DanBloomberg/leptonica/tags) (without the `v` tag name prefix) or `latest`(detect and build the current upstream latest version).

#### Default value

`latest`

### LEPTONICA_SOURCE_ARCHIVE_URL

Configures the URL to download Leptonica's source archive from.

#### Accepted values

Any URLs supported by the curl client should work.

#### Default value

<https://github.com/DanBloomberg/leptonica/releases/download/_LEPTONICA_VERSION_/leptonica-_LEPTONICA_VERSION_.tar.gz>

### TESSERACT_VERSION

Determine which version of Tesseract to build.

#### Accepted values

A Tesseract version number that is available from the Git repository tags (without the `v` tag name prefix) or `latest`(detect and build the current upstream latest version).

#### Default value

`latest`

### TESSERACT_SOURCE_ARCHIVE_URL

Configures the URL to download Tesseract's source archive from.

#### Accepted values

Any URLs supported by the curl client should work.

#### Default value

<https://github.com/tesseract-ocr/tesseract/archive/refs/tags/_TESSERACT_VERSION_.tar.gz>

### TESSERACT_ORANGE_DEBUG

Enables the debugging features for the Tesseract Orange builder, including but not limited to disabling clean up of the temporary directory.

#### Accepted values

* `true`: Enable debugging features
* `false`: Disable debugging features

#### Default value

`false`

### TESSERACT_ORANGE_PREFIX

Specifies the installation path prefix of the Tesseract Orange installation.

#### Default value

`/opt/tesseract-orange-_TESSERACT_ORANGE_VERSION_`

The `_TESSERACT_ORANGE_VERSION_` placeholder string will be automatically replaced to the distribution version of the Tesseract Orange source.

## References

Here are some third-party resources that are referenced during the development of this product:

* [tesseract-ocr/tesseract: Tesseract Open Source OCR Engine (main repository)](https://github.com/tesseract-ocr/tesseract)  
  The upstream project site.
* [Tesseract documentation | Tesseract OCR](https://tesseract-ocr.github.io/)  
  The upstream documentation site.
* [Compose Specification | Compose file reference | Reference | Docker Docs](https://docs.docker.com/compose/compose-file/)  
  For information of instantiating and configuring the product builder container
* [Getting started with the REST API - GitHub Docs](https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28)  
  For information regarding how to (properly) interact with the GitHub REST APIs.
* [Content-Disposition - HTTP | MDN](https://developer.mozilla.org/en-US/docs/web/http/headers/content-disposition)  
  Explains the usage and values of the `Content-Disposition` HTTP header.
* [README | Leptonica](http://www.leptonica.org/source/README.html)  
  Explains the specifics of building Leptonica from the source code.
* [Git - git-describe Documentation](https://git-scm.com/docs/git-describe)  
  Explains the command-line options of the `git describe` command.
* [Compilation guide for various platforms | tessdoc](https://tesseract-ocr.github.io/tessdoc/Compiling.html)  
  Explain the specifics of building Tesseract from its source code.
* [‎autogen.sh: Automating build setup | Google Gemini](https://gemini.google.com/share/badbb251c590)  
  [Autogen.sh in Software Development | OpenAI ChatGPT](https://chat.openai.com/share/e35e3f49-fafe-4ece-9b5b-e9aea523def5)  
  Explains the usage of the autogen.sh program.
* [GNU tar manual: Modifying File and Member Names](https://www.gnu.org/software/tar/manual/html_node/transform.html)  
  Explains how to transform the whole file names of the archive members while creating the deploy package archive.
* [zip - How to use multi-threading for creating and extracting tar.xz - Unix & Linux Stack Exchange](https://unix.stackexchange.com/questions/608207/how-to-use-multi-threading-for-creating-and-extracting-tar-xz)  
  Explains how to enable the multi-threading functionality of the `xz` program to cut down deployment package creation time.
* [ENVIRONMENT: man xz (1): Compress or decompress .xz and .lzma files](https://manpages.org/xz#environment)  
  Explains the differences between the `XZ_OPT` and `XZ_DEFAULTS` environment variables.

## Licensing

Unless otherwise noted, this product is licensed under [the version 3 of the GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html), or any of its recent versions you would prefer.

This work complies to the [REUSE Specification](https://reuse.software/spec/), refer [REUSE - Make licensing easy for everyone](https://reuse.software/) for info regarding the licensing of this product.
