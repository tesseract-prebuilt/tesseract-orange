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

* A recent version of the Docker Engine (or equivalent counterparts) software installation  
  For running the container for running the product build program(A.K.A. [the "Builder container"](#builder-container))
* A recent version of the Docker Compose container orchestration utility(or its equivalent counterparts)

### Builder container

This section documents the prerequisites of the product building container:

* GNU Bash  
  The runtime interpreter of the build program.  **Requires version >= 4.3**(name reference variable support to be specific).
* Ubuntu 22.04  
  The operating system image of the builder container, other recent versions of Ubuntu/Debian may be compatible but those are not tested as of now.  Other Linux distributions may be supported if there's a large userbase(patches welcome!)

## Environment variables that will change the prodoct builder's behavior

### TESSERACT_VERSION

Determine which version of Tesseract to build.

#### Accepted values

A Tesseract version number that is available from the Git repository tags (without the `v` tag name prefix) or `latest`(detect and build the current upstream latest version).

#### Default value

`latest`

## Reference

Here are some third-party resources that are referenced during the development of this product:

* [tesseract-ocr/tesseract: Tesseract Open Source OCR Engine (main repository)](https://github.com/tesseract-ocr/tesseract)  
  The upstream project site.
* [Tesseract documentation | Tesseract OCR](https://tesseract-ocr.github.io/)  
  The upstream documentation site.
* [Compose Specification | Compose file reference | Reference | Docker Docs](https://docs.docker.com/compose/compose-file/)  
  For information of instantiating and configuring the product builder container
* [Getting started with the REST API - GitHub Docs](https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28)  
  For information regarding how to (properly) interact with the GitHub REST APIs.

## Licensing

Unless otherwise noted, this product is licensed under [the version 3 of the GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html), or any of its recent versions you would prefer.

This work complies to the [REUSE Specification](https://reuse.software/spec/), refer [REUSE - Make licensing easy for everyone](https://reuse.software/) for info regarding the licensing of this product.
