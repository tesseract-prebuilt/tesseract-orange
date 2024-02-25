#!/usr/bin/env bash
# Build optimized Tesseract OCR engine from source
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
TESSERACT_VERSION="${TESSERACT_VERSION:-latest}"
TESSERACT_SOURCE_ARCHIVE_URL="${TESSERACT_SOURCE_ARCHIVE_URL:-"https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz"}"
TESSERACT_ORANGE_DEBUG="${TESSERACT_ORANGE_DEBUG:-false}"
TESSERACT_ORANGE_PREFIX="${TESSERACT_ORANGE_PREFIX:-/opt/tesseract-orange-_TESSERACT_ORANGE_VERSION_}"

LEPTONICA_VERSION="${LEPTONICA_VERSION:-latest}"
LEPTONICA_SOURCE_ARCHIVE_URL="${LEPTONICA_SOURCE_ARCHIVE_URL:-"https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz"}"

init(){
    local common_functions_file="${script_dir}/functions.sh"
    if ! test -e "${common_functions_file}"; then
        printf \
            'Error: This program requires the common functions file "%s" to exist.\n' \
            "${common_functions_file}" \
            1>&2
        exit 2
    fi

    # shellcheck source=functions.sh
    if ! source "${common_functions_file}"; then
        printf \
            'Error: Unable to load the common functions file "%s".\n' \
            "${common_functions_file}" \
            1>&2
        exit 2
    fi

    print_progress \
        'Tesseract Orange product build program' \
        =

    if ! check_runtime_parameters; then
        printf \
            'Error: The runtime parameter check has failed.\n' \
            1>&2
        exit 1
    fi

    # Silence warnings regarding unavailable debconf frontends
    export DEBIAN_FRONTEND=noninteractive

    local -a base_runtime_dependency_pkgs=(
        coreutils
    )
    if ! dpkg -s "${base_runtime_dependency_pkgs[@]}" &>/dev/null; then
        print_progress 'Installing base runtime dependency packages...'
        if ! \
            apt-get install \
                -y \
                "${base_runtime_dependency_pkgs[@]}"; then
            printf \
                'Error: Unable to install the base runtime dependency packages.\n' \
                1>&2
            return 2
        fi
    fi

    if ! prepare_software_sources; then
        printf \
            'Error: Unable to prepare the software sources.\n' \
            1>&2
        exit 2
    fi

    local cache_dir="${script_dir}/cache"
    if ! test -d "${cache_dir}"; then
        print_progress 'Creating the cache directory...'
        local -a mkdir_opts=(
            # Print progress report messages for better transparency
            --verbose
        )
        if ! mkdir "${mkdir_opts[@]}" "${cache_dir}"; then
            printf \
                'Error: Unable to create the cache directory.\n' \
                1>&2
            exit 2
        fi
    fi

    print_progress 'Determining the operation timestamp...'
    local operation_timestamp
    if ! operation_timestamp="$(date +%Y%m%d-%H%M%S)"; then
        printf \
            'Error: Unable to query the operation timestamp.\n' \
            1>&2
        exit 2
    else
        printf \
            'Info: Operation timestamp determined to be "%s".\n' \
            "${operation_timestamp}"
    fi

    print_progress 'Creating the temporary directory for build intermediate files...'
    if ! temp_dir="$(
        mktemp \
            --tmpdir \
            --directory \
            "${script_name}-${operation_timestamp}.XXXXXX"
        )"; then
        printf \
            'Error: Unable to create the temporary directory.\n' \
            1>&2
        exit 2
    else
        printf \
            'Info: "%s" temporary directory created.\n' \
            "${temp_dir}"
    fi

    print_progress 'Creating the source and build base directories...'
    local \
        source_basedir="${temp_dir}/source" \
        build_basedir="${temp_dir}/build"
    if ! mkdir --verbose "${source_basedir}" "${build_basedir}"; then
        printf \
            'Error: Unable to create the source and build base directory.\n' \
            1>&2
        exit 2
    fi

    print_progress 'Determining the Tesseract Orange distribution version string...'
    if ! determine_tesseract_orange_version_ensure_deps; then
        printf \
            'Error: Unable to ensure the dependencies of the determine_tesseract_orange_version function.\n' \
            1>&2
        exit 2
    fi

    local product_dir="${script_dir}"
    local tesseract_orange_version
    if ! tesseract_orange_version="$(
        determine_tesseract_orange_version \
            "${product_dir}" \
            "${operation_timestamp}"
        )"; then
        printf \
            'Error: Unabel to determine the Tesseract Orange distribution version string.\n' \
            1>&2
        exit 2
    else
        printf \
            'Info: Tesseract Orange distribution version determined to be "%s".\n' \
            "${tesseract_orange_version}"
    fi

    print_progress 'Determining the installation prefix path...'
    local tesseract_orange_prefix
    tesseract_orange_prefix="${TESSERACT_ORANGE_PREFIX//_TESSERACT_ORANGE_VERSION_/"${tesseract_orange_version}"}"
    printf \
        'Info: Installation prefix path determined to be "%s".\n' \
        "${tesseract_orange_prefix}"

    print_progress 'Determining which Leptonica version to build...'
    local leptonica_version
    if test "${LEPTONICA_VERSION}" == latest; then
        if ! query_latest_leptonica_version_ensure_deps; then
            printf \
                'Error: Unable to ensure the runtime dependencies for the query_latest_leptonica_version function.\n' \
                1>&2
            exit 2
        fi

        if ! leptonica_version="$(query_latest_leptonica_version)"; then
            printf \
                'Error: Unable to query the latest Leptonica version.\n' \
                1>&2
            exit 2
        fi

        printf \
            'Info: Will build current latest version of Leptonica("%s") determined from the GitHub References API response.\n' \
            "${leptonica_version}"
    else
        leptonica_version="${LEPTONICA_VERSION}"
        printf \
            'Info: Will build version "%s" of Leptonica specified from the LEPTONICA_VERSION environment variable.\n' \
            "${leptonica_version}"
    fi

    local leptonica_source_archive
    if ! acquire_leptonica_source_archive \
        leptonica_source_archive \
        "${leptonica_version}" \
        "${cache_dir}" \
        "${LEPTONICA_SOURCE_ARCHIVE_URL}"; then
        printf \
            'Error: Unable to acquire the "%s" version of the Leptonica source archive.\n' \
            "${leptonica_version}" \
            1>&2
        exit 2
    fi

    print_progress 'Extracting the Leptonica source archive...'
    local leptonica_source_dir="${source_basedir}/leptonica"
    if ! extract_software_archive \
        "${leptonica_source_archive}" \
        "${leptonica_source_dir}"; then
        printf \
            'Error: Unable to extract the Leptonica source archive.\n' \
            1>&2
        exit 2
    fi

    local leptonica_build_dir="${build_basedir}/leptonica"
    if ! configure_leptonica_build \
        "${leptonica_source_dir}" \
        "${leptonica_build_dir}" \
        "${tesseract_orange_prefix}"; then
        printf \
            'Error: Unable to configure the Leptonica build.\n' \
            1>&2
        exit 2
    fi

    if ! build_leptonica "${leptonica_build_dir}"; then
        printf \
            'Error: Unable to build Leptonica from its source code.\n' \
            1>&2
        exit 2
    fi

    if ! install_leptonica "${leptonica_build_dir}"; then
        printf \
            'Error: Unable to install Leptonica to the Tesseract Orange installation prefix(%s).\n' \
            "${tesseract_orange_prefix}" \
            1>&2
        exit 2
    fi

    print_progress 'Determining which Tesseract version to build...'
    local tesseract_version
    if test "${TESSERACT_VERSION}" == latest; then
        if ! query_latest_tesseract_version_ensure_deps; then
            printf \
                'Error: Unable to ensure the runtime dependencies for the query_latest_tesseract_version function.\n' \
                1>&2
            exit 2
        fi

        if ! tesseract_version="$(query_latest_tesseract_version)"; then
            printf \
                'Error: Unable to query the latest tesseract version.\n' \
                1>&2
            exit 2
        fi

        printf \
            'Info: Will build current latest version of Tesseract("%s") determined from the GitHub References API response.\n' \
            "${tesseract_version}"
    else
        tesseract_version="${TESSERACT_VERSION}"
        printf \
            'Info: Will build version "%s" of Tesseract specified from the TESSERACT_VERSION environment variable.\n' \
            "${tesseract_version}"
    fi

    local tesseract_source_archive
    if ! acquire_tesseract_source_archive \
        tesseract_source_archive \
        "${tesseract_version}" \
        "${cache_dir}" \
        "${TESSERACT_SOURCE_ARCHIVE_URL}"; then
        printf \
            'Error: Unable to acquire the "%s" version of the Tesseract source archive.\n' \
            "${tesseract_version}" \
            1>&2
        exit 2
    fi

    print_progress 'Extracting the Tesseract source archive...'
    local tesseract_source_dir="${source_basedir}/tesseract"
    if ! extract_software_archive \
        "${tesseract_source_archive}" \
        "${tesseract_source_dir}"; then
        printf \
            'Error: Unable to extract the Tesseract source archive.\n' \
            1>&2
        exit 2
    fi

    local tesseract_build_dir="${build_basedir}/tesseract"
    if ! configure_tesseract_build \
        "${tesseract_source_dir}" \
        "${tesseract_build_dir}" \
        "${tesseract_orange_prefix}"; then
        printf \
            'Error: Unable to configure the Tesseract build.\n' \
            1>&2
        exit 2
    fi

    if ! build_tesseract "${tesseract_build_dir}"; then
        printf \
            'Error: Unable to build the Tesseract software from its source code.\n' \
            1>&2
        exit 2
    fi

    if ! install_tesseract "${tesseract_build_dir}"; then
        printf \
            'Error: Unable to install the Tesseract software to the Tesseract installation prefix.\n' \
            1>&2
        exit 2
    fi

    print_progress \
        'Operation completed without errors.'
}

# Configure the build of the Tesseract software
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
configure_tesseract_build(){
    local source_dir="${1}"; shift
    local build_dir="${1}"; shift
    local tesseract_orange_prefix="${1}"; shift

    print_progress 'Configuring the Tesseract build...'

    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            'Error: Unable to query the operating system distribution identifier.\n' \
            1>&2
        return 2
    fi

    local build_dependency_packages_missing=false
    local -a build_dependency_pkgs=(
        # The GNU build system used for building Tesseract
        autoconf
        automake
        libtool

        # C++ compiler
        g++

        # For locating depending library installations
        pkg-config

        # For compressed model files support
        libarchive-dev

        # For building training tools
        libcairo2-dev
        libicu-dev
        libpango1.0-dev

        # For image URL processing support
        libcurl4-openssl-dev

        # For OpenCL support
        ocl-icd-opencl-dev
    )
    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${build_dependency_pkgs[@]}" &>/dev/null; then
                build_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                'Error: Operating system distribution(ID=%s) not supported.\n' \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${build_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the build dependency packages for the Tesseract software...\n'

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${build_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the build dependency packages for the Tesseract software.\n' \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[1]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi

    printf \
        'Info: Changing the working directory to the Tesseract source directory...\n'
    if ! cd "${source_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Tesseract source directory(%s).\n' \
            "${source_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Running the GNU Autotools build system file generation program of the Tesseract software...\n'
    if ! "${source_dir}/autogen.sh"; then
        printf \
            'Error: Unable to run the GNU Autotools build system file generation program of the Tesseract software.\n' \
            1>&2
        return 1
    fi

    if ! test -e "${build_dir}"; then
        printf \
            'Info: Creating the Tesseract build directory...\n'
        if ! mkdir "${build_dir}"; then
            printf \
                'Error: Unable to create the Tesseract build directory.\n' \
                1>&2
            return 2
        fi
    fi

    printf \
        'Info: Changing the working directory to the Tesseract build directory...\n'
    if ! cd "${build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Tesseract build directory(%s).\n' \
            "${build_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the Tesseract build configuration program...\n'
    local -a configure_envs=(
        PKG_CONFIG_PATH="${tesseract_orange_prefix}/lib/pkgconfig"
    )
    local -a configure_opts=(
        # Specify the installation path prefix
        --prefix="${tesseract_orange_prefix}"

        # Disable development feature to speed up one time build
        --disable-dependency-tracking
        --disable-debug

        # Don't build unused documentation files to speed up build
        --disable-doc

        # Enable experimental OpenCL acceleration
        --enable-opencl

        # Don't build unused static libraries to speed up build
        --disable-static

    )
    if ! env "${configure_envs[@]}" \
        "${source_dir}/configure" "${configure_opts[@]}"; then
        printf \
            'Error: Unable to run the Tesseract build configuration program.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Tesseract build configured successfully.\n'
}

# Install the Tesseract software to the installation prefix directory
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
install_tesseract(){
    local tesseract_build_dir="${1}"; shift

    print_progress 'Installing Tesseract...'

    printf \
        'Info: Changing the working directory to the Tesseract build directory(%s)...\n' \
        "${tesseract_build_dir}"
    if ! cd "${tesseract_build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Tesseract build directory(%s).\n' \
            "${tesseract_build_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the "install" target of the Tesseract makefile...\n'
    if ! make install; then
        printf \
            'Error: Unable to run the "install" target of the Tesseract makefile.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the "training-install" target of the Tesseract makefile..\n'
    if ! make training-install; then
        printf \
            'Error: Unable to run the "training-install" target of the Tesseract makefile.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Tesseract installed successfully.\n'
}

# Build Tesseract from its source code
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
build_tesseract(){
    local build_dir="${1}"; shift

    print_progress 'Building Tesseract from its source code...'

    if ! cd "${build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Tesseract build directory(%s).\n' \
            "${build_dir}" \
            1>&2
        return 2
    fi

    local -i cpu_cores
    if ! cpu_cores="$(nproc)"; then
        printf \
            'Error: Unable to query the number of the CPU cores.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the default make recipe...\n'
    local -a make_opts=(
        --jobs="${cpu_cores}"
    )
    if ! make "${make_opts[@]}"; then
        printf \
            'Error: Unable to run the default make recipe.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the default make recipe...\n'
    local -a make_opts=(
        --jobs="${cpu_cores}"
    )
    if ! make "${make_opts[@]}"; then
        printf \
            'Error: Unable to run the default make recipe.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the "training" make recipe...\n'
    if ! make "${make_opts[@]}" training; then
        printf \
            'Error: Unable to run the "training" make recipe.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Tesseract build successfully.\n'
}

# Download and cache the Tesseract source archive file
acquire_tesseract_source_archive(){
    local -n tesseract_source_archive_ref="${1}"; shift
    local tesseract_version="${1}"; shift
    local cache_dir="${1}"; shift
    local tesseract_source_archive_url="${1}"; shift

    print_progress 'Acquiring the Tesseract source archive...'

    # Download archive URL may be invalid for TESSERACT_VERSION=latest
    if test "${tesseract_source_archive_url}" != "${tesseract_source_archive_url//latest/}"; then
        tesseract_source_archive_url="${tesseract_source_archive_url//latest/"${tesseract_version}"}"
    fi

    printf \
        'Info: Determining the download filename for the Tesseract source archive URL(%s)...\n' \
        "${tesseract_source_archive_url}"
    local download_filename
    if ! download_filename="$(determine_url_download_filename "${tesseract_source_archive_url}")"; then
        printf \
            'Error: Unable to determine the download filename for Tesseract source archive URL "%s".\n' \
            "${tesseract_source_archive_url}" \
            1>&2
        return 2
    fi
    printf \
        'Info: Tesseract source archive download filename determined to be "%s".\n' \
        "${download_filename}"

    local downloaded_tesseract_source_archive="${cache_dir}/${download_filename}"
    if ! test -e "${downloaded_tesseract_source_archive}"; then
        printf \
            'Info: Downloading Tesseract source archive from URL(%s)...\n' \
            "${tesseract_source_archive_url}"

        local -a curl_opts=(
            # Use filename suggested by the remote server as the downloaded
            # file filename
            --remote-name
            --remote-header-name

            # Follow URL redirection instructed by the remote server
            --location

            # Download to cache directory
            --output-dir "${cache_dir}"

            # Return non-zero exit status when HTTP error occurs
            --fail

            # Do not show progress meter but keep error messages
            --silent
            --show-error

        )
        if ! curl "${curl_opts[@]}" "${tesseract_source_archive_url}"; then
            printf \
                'Error: Unable to download the Tesseract source archive file.\n' \
                1>&2
            return 2
        else
            printf \
                'Info: Tesseract source archive file downloaded to "%s".\n' \
                "${downloaded_tesseract_source_archive}"
        fi
    else
        printf \
            'Info: Using cached Tesseract source archive file "%s".\n' \
            "${downloaded_tesseract_source_archive}"
    fi

    # FALSE POSITIVE: Variable references are used externally
    # shellcheck disable=SC2034
    tesseract_source_archive_ref="${downloaded_tesseract_source_archive}"
}

# Install leptonica to the installation prefix directory
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
install_leptonica(){
    local leptonica_build_dir="${1}"; shift

    print_progress 'Installing Leptonica...'

    printf \
        'Info: Changing the working directory to the Leptonica build directory(%s)...\n' \
        "${leptonica_build_dir}"
    if ! cd "${leptonica_build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Leptonica build directory(%s).\n' \
            "${leptonica_build_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the install target of the Leptonica makefile...\n'
    if ! make install; then
        printf \
            'Error: Unable to run the install target of the Leptonica makefile.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Leptonica installed successfully.\n'
}

# Build Leptonica from its source code
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
build_leptonica(){
    local build_dir="${1}"; shift

    print_progress 'Building Leptonica from its source code...'

    printf \
        'Info: Changing the working directory to the Leptonica build directory(%s)...\n' \
        "${build_dir}"
    if ! cd "${build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Leptonica build directory(%s).\n' \
            "${build_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Info: Querying the number of the CPU cores...\n'
    local -i cpu_cores
    if ! cpu_cores="$(nproc)"; then
        printf \
            'Error: Unable to query the number of the CPU cores.\n' \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the default make recipe...\n'
    local -a make_opts=(
        --jobs="${cpu_cores}"
    )
    if ! make "${make_opts[@]}"; then
        printf \
            'Error: Unable to run the default make recipe.\n' \
            1>&2
        return 2
    fi
}

# Configure the build of the Leptonica software
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
configure_leptonica_build(){
    local leptonica_source_dir="${1}"; shift
    local leptonica_build_dir="${1}"; shift
    local install_prefix="${1}"; shift

    print_progress 'Configuring the Leptonica build...'

    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            'Error: Unable to query the operating system distribution identifier.\n' \
            1>&2
        return 2
    fi

    local build_dependency_packages_missing=false
    local -a leptonica_build_dependency_pkgs=(
        # Dependencies for the build configuration program
        binutils
        file

        # C compiler
        gcc

        # For GIF support
        libgif-dev

        # For JPEG support
        libjpeg-dev

        # For JPEG 2000 support
        libopenjp2-7-dev

        # For PNG support
        libpng-dev

        # For TIFF support
        libtiff-dev

        # For WEBP support
        libwebp-dev

        # For running build automation
        make

        # For external dependency checking
        pkg-config

        # For zlib support
        zlib1g-dev
    )
    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${leptonica_build_dependency_pkgs[@]}" &>/dev/null; then
                build_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                'Error: Operating system distribution(ID=%s) not supported.\n' \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${build_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the build dependency packages for the Leptonica software...\n'

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${leptonica_build_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the build dependency packages for the Leptonica software.\n' \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[1]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi

    if ! test -e "${leptonica_build_dir}"; then
        printf \
            'Info: Creating the Leptonica build directory...\n'
        if ! mkdir "${leptonica_build_dir}"; then
            printf \
                'Error: Unable to create the Leptonica build directory.\n' \
                1>&2
            return 2
        fi
    fi

    printf \
        'Info: Changing the working directory to the Leptonica build directory...\n'
    if ! cd "${leptonica_build_dir}"; then
        printf \
            'Error: Unable to change the working directory to the Leptonica build directory(%s).\n' \
            "${leptonica_build_dir}" \
            1>&2
        return 2
    fi

    printf \
        'Info: Running the Leptonica build configuration program...\n'
    local -a leptonica_configure_envs=(
        # Disable debugging symbols
        CFLAGS=-O2
    )
    local -a leptonica_configure_opts=(
        # Specify the installation directory path prefix
        --prefix="${install_prefix}"

        # Disable developer options that slow down the build
        --disable-dependency-tracking

        # Don't build static library
        --disable-static

        # Don't build unused executable programs
        --disable-programs

        # Enable zlib support
        --with-zlib

        # Enable PNG support
        --with-libpng

        # Enable JPEG support
        --with-jpeg

        # Enable GIF support
        --with-giflib

        # Enable TIFF support
        --with-libtiff

        # Enable Webp support
        --with-libwebp

        # Enable libwebpmux support
        --with-libwebpmux

        # Enable JPEG 2000 support
        --with-libopenjpeg
    )
    if ! \
        env \
            "${leptonica_configure_envs[@]}" \
            "${leptonica_source_dir}/configure" \
            "${leptonica_configure_opts[@]}"; then
        printf \
            'Error: Unable to run the Leptonica build configuration program.\n' \
            1>&2
        return 2
    fi
}

# Acquire the Leptonica source archive from the given URL, unless it is
# already available in the cache directory
acquire_leptonica_source_archive(){
    local -n leptonica_source_archive_ref="${1}"; shift
    local leptonica_version="${1}"; shift
    local cache_dir="${1}"; shift
    local leptonica_source_archive_url="${1}"; shift

    print_progress 'Acquiring the Leptonica source archive...'

    # Download archive URL may be invalid for TESSERACT_VERSION=latest
    if test "${leptonica_source_archive_url}" != "${leptonica_source_archive_url//latest/}"; then
        leptonica_source_archive_url="${leptonica_source_archive_url//latest/"${leptonica_version}"}"
    fi

    printf \
        'Info: Determining the download filename for the Leptonica source archive URL(%s)...\n' \
        "${leptonica_source_archive_url}"
    local download_filename
    if ! download_filename="$(determine_url_download_filename "${leptonica_source_archive_url}")"; then
        printf \
            'Error: Unable to determine the download filename for Leptonica source archive URL "%s".\n' \
            "${leptonica_source_archive_url}" \
            1>&2
        return 2
    fi
    printf \
        'Info: Leptonica source archive download filename determined to be "%s".\n' \
        "${download_filename}"

    local downloaded_leptonica_source_archive="${cache_dir}/${download_filename}"
    if ! test -e "${downloaded_leptonica_source_archive}"; then
        printf \
            'Info: Downloading Leptonica source archive from URL(%s)...\n' \
            "${leptonica_source_archive_url}"

        local -a curl_opts=(
            # Use filename suggested by the remote server as the downloaded
            # file filename
            --remote-name
            --remote-header-name

            # Follow URL redirection instructed by the remote server
            --location

            # Download to cache directory
            --output-dir "${cache_dir}"

            # Return non-zero exit status when HTTP error occurs
            --fail

            # Do not show progress meter but keep error messages
            --silent
            --show-error

        )
        if ! curl "${curl_opts[@]}" "${leptonica_source_archive_url}"; then
            printf \
                'Error: Unable to download the Leptonica source archive file.\n' \
                1>&2
            return 2
        else
            printf \
                'Info: Leptonica source archive file downloaded to "%s".\n' \
                "${downloaded_leptonica_source_archive}"
        fi
    else
        printf \
            'Info: Using cached Leptonica source archive file "%s".\n' \
            "${downloaded_leptonica_source_archive}"
    fi

    # FALSE POSITIVE: Variable references are used externally
    # shellcheck disable=SC2034
    leptonica_source_archive_ref="${downloaded_leptonica_source_archive}"
}

# Ensure the runtime dependencies of the
# query_latest_leptonica_version function, requires to be run as the
# superuser(root).
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite error
# * 2: Generic error
query_latest_leptonica_version_ensure_deps(){
    local -a runtime_dependency_pkgs=(
        curl
        jq
    )
    if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
        printf \
            'Info: Installing runtime dependencies for the "query_latest_leptonica_version" function...\n'
        if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
            printf \
                'Error: Unable to install the runtime dependencies packages for the "query_latest_leptonica_version" function.\n' \
                1>&2
            return 2
        fi
    fi
}

# Determine Leptonica version to be built (when LEPTONICA_VERSION is set
# to "latest") by calling the GitHub APIs
#
# Standard output: version to be built(without the `v` prefix)
query_latest_leptonica_version(){
    local -a curl_opts=(
        --request GET
        --header 'X-GitHub-Api-Version: 2022-11-28'
        --header 'Accept: application/vnd.github+json'
        --header 'User-Agent: Tesseract Orange Builder <https://gitlab.com/tesseract-prebuilt/tesseract-orange/-/issues>'

        --silent
        --show-error
    )
    if ! github_list_matching_references_response="$(
        curl "${curl_opts[@]}" https://api.github.com/repos/DanBloomberg/leptonica/git/matching-refs/tags/
        )"; then
        printf \
            'Error: Unable to query the Leptonica repository Git tag list information from GitHub.\n' \
            1>&2
        return 1
    fi

    local last_git_tag_reference
    local -a jq_opts=(
        --raw-output
    )
    if ! last_git_tag_reference="$(
        jq \
            "${jq_opts[@]}" \
            '.[-1].ref' \
            <<<"${github_list_matching_references_response}"
        )"; then
        printf \
            'Error: Unable to parse out the last Git tag reference name from the Git tag list information.\n' \
            1>&2
        return 1
    fi

    local last_git_tag="${last_git_tag_reference##*/}"
    printf -- '%s' "${last_git_tag}"
}

query_latest_tesseract_version_ensure_deps(){
    local -a runtime_dependency_pkgs=(
        curl
        jq
    )
    if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
        printf \
            'Info: Installing runtime dependencies for the query_latest_tesseract_version function...\n'
        if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
            printf \
                'Error: Unable to install the runtime dependencies packages for the query_latest_tesseract_version function.\n' \
                1>&2
            return 2
        fi
    fi
}

# Determine tesseract version to be built (when TESSERACT_VERSION is set
# to "latest") by calling the GitHub APIs
#
# Standard output: version to be built(without the `v` prefix)
query_latest_tesseract_version(){
    local -a curl_opts=(
        --request GET
        --header 'X-GitHub-Api-Version: 2022-11-28'
        --header 'Accept: application/vnd.github+json'
        --header 'User-Agent: Tesseract Orange Builder <https://gitlab.com/tesseract-prebuilt/tesseract-orange/-/issues>'

        --silent
        --show-error
    )
    if ! github_list_matching_references_response="$(
        curl "${curl_opts[@]}" https://api.github.com/repos/tesseract-ocr/tesseract/git/matching-refs/tags/
        )"; then
        printf \
            'Error: Unable to query the Tesseract repository Git tag list information from GitHub.\n' \
            1>&2
        return 1
    fi

    local last_git_tag_reference
    local -a jq_opts=(
        --raw-output
    )
    if ! last_git_tag_reference="$(
        jq \
            "${jq_opts[@]}" \
            '.[-1].ref' \
            <<<"${github_list_matching_references_response}"
        )"; then
        printf \
            'Error: Unable to parse out the last Git tag reference name from the Git tag list information.\n' \
            1>&2
        return 1
    fi

    local last_git_tag="${last_git_tag_reference##*/}"
    printf -- '%s' "${last_git_tag}"
}

check_runtime_parameters(){
    print_progress 'Checking the runtime parameters of this program...'

    if ! check_running_user; then
        printf \
            'Error: Running user check failed.\n' \
            1>&2
        return 2
    fi
}

# Determine the type of the specified archive file
#
# Standard output: The determined file type:
#
# * tarball: Uncompressed tarball
# * tarball-bzip2: bzip2-compressed tarball
# * tarball-gzip: gzip-compressed tarball
# * tarball-xz: XZ-compressed tarball
# * zip: ZIP archive
#
# Return values:
#
# * 0: Check successful
# * 1: Prerequisite error
# * 2: Generic error
# * 3: Archive type unknown
determine_archive_file_type(){
    local archive_file="${1}"; shift

    if ! test -e "${archive_file}"; then
        printf \
            '%s: Error: The specified archive file does not exist.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    local determined_archive_type=
    if test "${archive_file%.tar}" != "${archive_file}"; then
        determined_archive_type=tarball
    fi

    if test "${archive_file%.zip}" != "${archive_file}"; then
        determined_archive_type=zip
    fi

    if test "${archive_file%.tar.*}" != "${archive_file}"; then
        local tarball_filename_suffix="${archive_file##*.}"
        case "${tarball_filename_suffix}" in
            bz2)
                determined_archive_type=tarball-bzip2
            ;;
            gz)
                determined_archive_type=tarball-gzip
            ;;
            xz)
                determined_archive_type=tarball-xz
            ;;
            *)
                # Not found by default, do nothing
                :
            ;;
        esac
    fi

    if test -z "${determined_archive_type}"; then
        return 3
    fi

    printf '%s' "${determined_archive_type}"
}

# Ensure runtime dependencies for the list_archive_memebers_ensure_deps function
#
# Return values:
#
# * 0: Successful
# * 1: Prerequisite error
# * 2: Generic error
list_archive_memebers_ensure_deps(){
    local software_archive="${1}"

    local archive_type
    if ! archive_type="$(determine_archive_file_type "${software_archive}")"; then
        printf \
            '%s: Error: Unable to determine the type of the "%s" software archive file.\n' \
            "${FUNCNAME[0]}" \
            "${software_archive}" \
            1>&2
        return 2
    fi

    local -a runtime_dependency_pkgs=()

    case "${archive_type}" in
        tarball)
            runtime_dependency_pkgs+=(tar)
        ;;
        tarball-bzip2)
            runtime_dependency_pkgs+=(bzip2 tar)
        ;;
        tarball-gzip)
            runtime_dependency_pkgs+=(gzip tar)
        ;;
        tarball-xz)
            runtime_dependency_pkgs+=(tar xz)
        ;;
        zip)
            runtime_dependency_pkgs+=(unzip)
        ;;
        *)
            printf \
                '%s: Error: Unsupported archive type "%s".\n' \
                "${FUNCNAME[1]}" \
                "${archive_type}" \
                1>&2
            return 2
        ;;
    esac

    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[1]}" \
            1>&2
        return 1
    fi

    local runtime_dependency_packages_missing=false
    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to query the operating system distribution identifier.\n' \
            "${FUNCNAME[1]}" \
            1>&2
        return 2
    fi

    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
                runtime_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                "${FUNCNAME[1]}" \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${runtime_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the runtime dependency packages for the "%s" function...\n' \
            "${FUNCNAME[1]}"

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the runtime dependency packages for the "%s" function.\n' \
                        "${FUNCNAME[1]}" \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[1]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi
}

# List all members of the specified archive file, one per line
#
# Return values:
#
# * 0: Successful
# * 1: Prerequisite error
# * 2: Generic error
list_archive_memebers(){
    local archive_file="${1}"; shift

    if ! list_archive_memebers_ensure_deps "${archive_file}"; then
        printf \
            'Error: Unable to ensure the runtime dependencies for the "%s" function.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -e "${archive_file}"; then
        printf \
            '%s: Error: The specified archive file(%s) does not exist.\n' \
            "${FUNCNAME[0]}" \
            "${archive_file}" \
            1>&2
        return 2
    fi

    local archive_type
    if ! archive_type="$(determine_archive_file_type "${archive_file}")"; then
        printf \
            '%s: Error: Unable to determine the type of the "%s" archive file.\n' \
            "${FUNCNAME[0]}" \
            "${archive_file}" \
            1>&2
        return 2
    fi

    case "${archive_type}" in
        tarball*)
            local -a tar_opts=(
                --list
                --file "${archive_file}"
            )
            if ! tar "${tar_opts[@]}"; then
                printf \
                    '%s: Error: Error occurred when trying to list the members of the "%s" archive file.\n' \
                    "${FUNCNAME[0]}" \
                    "${archive_file}" \
                    1>&2
                return 2
            fi
        ;;
        *)
            printf \
                '%s: Error: Archive type of the specified archive file(%s) is unsupported.\n' \
                "${FUNCNAME[0]}" \
                "${archive_file}" \
                1>&2
            return 1
        ;;
    esac
}

# Ensure runtime dependencies for the extract_software_archive function
#
# Return values:
#
# * 0: Successful
# * 1: Prerequisite error
# * 2: Generic error
extract_software_archive_ensure_deps(){
    local software_archive="${1}"

    local archive_type
    if ! archive_type="$(determine_archive_file_type "${software_archive}")"; then
        printf \
            '%s: Error: Unable to determine the type of the "%s" software archive file.\n' \
            "${FUNCNAME[0]}" \
            "${software_archive}" \
            1>&2
        return 2
    fi

    local -a runtime_dependency_pkgs=()

    case "${archive_type}" in
        tarball)
            runtime_dependency_pkgs+=(tar)
        ;;
        tarball-bzip2)
            runtime_dependency_pkgs+=(bzip2 tar)
        ;;
        tarball-gzip)
            runtime_dependency_pkgs+=(gzip tar)
        ;;
        tarball-xz)
            runtime_dependency_pkgs+=(tar xz)
        ;;
        zip)
            runtime_dependency_pkgs+=(unzip)
        ;;
        *)
            printf \
                '%s: Error: Unsupported archive type "%s".\n' \
                "${FUNCNAME[1]}" \
                "${archive_type}" \
                1>&2
            return 2
        ;;
    esac

    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[1]}" \
            1>&2
        return 1
    fi

    local runtime_dependency_packages_missing=false
    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to query the operating system distribution identifier.\n' \
            "${FUNCNAME[1]}" \
            1>&2
        return 2
    fi

    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
                runtime_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                "${FUNCNAME[1]}" \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${runtime_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the runtime dependency packages for the "%s" function...\n' \
            "${FUNCNAME[1]}"

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the runtime dependency packages for the "%s" function.\n' \
                        "${FUNCNAME[1]}" \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[1]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi
}

# Convert specified path into matching POSIX extended regular expression
#
# Standard output: Resulting regular expression string
convert_path_to_regex(){
    local path="${1}"; shift

    local matching_regex
    matching_regex="${path//./'\.'}"
    matching_regex="${path//+/'\+'}"

    printf '%s' "${matching_regex}"
}

# Extract software archive's content into specific directory, if there's
# only one folder in the first level then the first level directory is
# stripped.  Currently only tar archives are supported.
#
# Return values:
#
# * 0: Extraction successful
# * 1: Prerequisite error
# * 2: Generic error
extract_software_archive(){
    local archive_file="${1}"; shift
    local target_dir="${1}"; shift

    if ! extract_software_archive_ensure_deps "${archive_file}"; then
        printf \
            'Error: Unable to ensure the runtime dependencies for the "%s" function.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -e "${archive_file}"; then
        printf \
            '%s: Error: The specified archive(%s) does not exist.\n' \
            "${FUNCNAME[0]}" \
            "${archive_file}" \
            1>&2
        return 2
    fi

    local archive_type
    if ! archive_type="$(determine_archive_file_type "${archive_file}")"; then
        printf \
            '%s: Error: Unable to determine the type of the "%s" archive file.\n' \
            "${FUNCNAME[0]}" \
            "${archive_file}" \
            1>&2
        return 2
    fi

    case "${archive_type}" in
        tarball*)
            local -a tar_opts=(
                --list
                --file="${archive_file}"
            )
            if ! archive_members_raw="$(tar "${tar_opts[@]}")"; then
                printf \
                    'Error: Unable to list members of the "%s" tar archive file.\n' \
                    "${archive_file}" \
                    1>&2
                return 2
            fi
        ;;
        *)
            printf \
                'Error: Archive type of the specified archive file(%s) is unsupported.\n' \
                "${archive_file}" \
                1>&2
            return 1
        ;;
    esac

    local -a archive_members=()
    if ! mapfile -t archive_members <<<"${archive_members_raw}"; then
        printf \
            '%s: Error: Unable to load the archive members list into the archive_members array.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    local \
        flag_archive_has_single_leading_dir=true \
        flag_archive_has_leading_dir=false \
        leading_folder

    # If the archive is empty, this archive doesn't have a leading folder
    if test "${#archive_members[@]}" -eq 0; then
        flag_archive_has_single_leading_dir=false
    else
        local regex_directory_path='/$'
        for member in "${archive_members[@]}"; do
            if [[ "${member}" =~ ${regex_directory_path} ]]; then
                flag_archive_has_leading_dir=true
                leading_folder="${member%%/*}/"
                break
            fi
        done

        if test "${flag_archive_has_leading_dir}" == false; then
            # If no leading folder exist his archive doesn't have a leading
            # folder
            flag_archive_has_single_leading_dir=false
        else
            local leading_folder_matching_regex
            if ! leading_folder_matching_regex="^$(
                convert_path_to_regex "${leading_folder}"
                )"; then
                printf \
                    '%s: Error: Unable to convert path "%s" to matching regular expression.\n' \
                    "${FUNCNAME[0]}" \
                    "${leading_folder}" \
                    1>&2
                return 2
            fi

            for member in "${archive_members[@]}"; do
                if ! [[ "${member}" =~ ${leading_folder_matching_regex} ]]; then
                    # Different leading member found, this archive doesn't have
                    # a single leading folder
                    flag_archive_has_single_leading_dir=false
                fi
            done
        fi
    fi

    if test "${flag_archive_has_single_leading_dir}" == true; then
        printf \
            'Info: The "%s" archive file has a single leading directory, which will be stripped during extraction.\n' \
            "${archive_file}"
    fi

    if ! test -e "${target_dir}"; then
        printf \
            'Info: Creating the "%s" extraction target directory...\n' \
            "${target_dir}"
        if ! mkdir "${target_dir}"; then
            printf \
                '%s: Error: Unable to create the "%s" target directory.\n' \
                "${FUNCNAME[0]}" \
                "${target_dir}" \
                1>&2
            return 2
        fi
    fi

    case "${archive_type}" in
        tarball*)
            local -a tar_opts=(
                --extract
                --directory="${target_dir}"
                --file="${archive_file}"
            )

            if test "${flag_archive_has_single_leading_dir}" == true; then
                # Strip the undeterministic leading folder
                tar_opts+=(--strip-components=1)
            fi

            printf \
                'Info: Extracting the "%s" tar archive file to the "%s" target directory...\n' \
                "${archive_file}" \
                "${target_dir}"
            if ! tar "${tar_opts[@]}"; then
                printf \
                    'Error: Unable to extract the "%s" tar archive file to the "%s" target directory.\n' \
                    "${archive_file}" \
                    "${target_dir}" \
                    1>&2
                return 2
            fi
        ;;
        *)
            printf \
                'Error: Archive type of the specified archive file(%s) is unsupported.\n' \
                "${archive_file}" \
                1>&2
            return 1
        ;;
    esac

    local -a shell_opts=(
        # Allow '*' wildcard pattern to also match hidden files
        dotglob

        # Output nothing when expand result is empty
        nullglob
    )
    for shell_option in "${shell_opts[@]}"; do
        if ! shopt -s "${shell_option}"; then
            printf \
                '%s: Error: Unable to set the "%s" shell option.\n' \
                "${FUNCNAME[0]}" \
                "${shell_option}" \
                1>&2
            return 2
        fi
    done

    if ! cd "${target_dir}"; then
        printf \
            'Error: Unable to switch the working directory to the target directory(%s).\n' \
            "${target_dir}" \
            1>&2
        return 2
    fi

    local -a target_dir_members=(*)
    if test "${#target_dir_members[@]}" -eq 0; then
        printf \
            'Warning: Archive extracted successfully, however the target directory is empty.\n' \
            1>&2
    else
        printf \
            'Info: Archive extracted successfully with the following target directory content available:\n\n'
        for member in "${target_dir_members[@]}"; do
            if test -d "${member}"; then
                printf \
                    '* %s/\n' \
                    "${member}"
            else
                printf \
                    '* %s\n' \
                    "${member}"
            fi
        done
    fi
}

# Ensure the runtime dependencies for the determine_tesseract_orange_version
# function
determine_tesseract_orange_version_ensure_deps(){
    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local -a runtime_dependency_pkgs=(
        # For determining the version from the Git repository
        git
    )

    local runtime_dependency_packages_missing=false
    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to query the operating system distribution identifier.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
                runtime_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                "${FUNCNAME[0]}" \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${runtime_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the runtime dependency packages for the determine_tesseract_orange_version function...\n'

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the runtime dependency packages for the determine_tesseract_orange_version function.\n' \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[0]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi
}

# Determine version of the Tesseract Orange distribution, according to
# info gathered from the environment(which may be vague or incorrect)
#
# Standard output: Determined version string
determine_tesseract_orange_version(){
    local product_dir="${1}"; shift
    local operation_timestamp="${1}"; shift

    local flag_use_vague_version_number=false
    local tesseract_orange_version
    local product_git_repository="${product_dir}/.git"
    if test -e "${product_git_repository}"; then
        local git_describe_output
        local -a git_opts=(
            # Use product directory as the Git working copy directory
            -C "${product_dir}"
        )
        local -a git_describe_opts=(
            # Show uniquely abbreviated commit object as fallback
            --always

            # Add marker if the working copy is dirty
            --dirty

            # Show tags
            --tags
        )
        if ! git_describe_output="$(git "${git_opts[@]}" describe "${git_describe_opts[@]}")"; then
            printf \
                'Warning: Unable to determine the version via the "git describe" command, will use vague version number as a fallback.\n' \
                1>&2
            flag_use_vague_version_number=true
        else
            if test "${TESSERACT_ORANGE_DEBUG}" == true; then
                printf \
                    'DEBUG: Using "%s" from the "git describe" command to determine Tesseract Orange distribution version.\n' \
                    "${git_describe_output}" \
                    1>&2
            fi

            tesseract_orange_version="${git_describe_output#v}"
        fi
    else
        local product_dir_name="${product_dir##*/}"
        local regex_product_prefix='^tesseract-orange-'
        if ! [[ "${product_dir_name}" =~ ${regex_product_prefix} ]]; then
            printf \
                'Warning: The product directory name is not valid Tesseract Orange distribution identifier name, will use vague version number as a fallback.\n' \
                1>&2
            flag_use_vague_version_number=true
        else
            tesseract_orange_version="${product_dir_name#tesseract-orange-}"
        fi
    fi

    if test "${flag_use_vague_version_number}" == true; then
        tesseract_orange_version="unknown-${operation_timestamp}"
    fi

    if test "${TESSERACT_ORANGE_DEBUG}" == true; then
        printf \
            '%s: DEBUG: Tesseract Orange distribution version determined to be "%s".\n' \
            "${FUNCNAME[0]}" \
            "${tesseract_orange_version}" \
            1>&2
    fi

    printf '%s' "${tesseract_orange_version}"
}

determine_url_download_filename_ensure_deps(){
    if ! check_package_manager_commands; then
        printf \
            '%s: Error: Package manager command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local -a runtime_dependency_pkgs=(
        # For sending HTTP requests
        curl

        # For matching HTTP response headers
        grep
    )

    local runtime_dependency_packages_missing=false
    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to query the operating system distribution identifier.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    case "${distro_id}" in
        debian|ubuntu)
            if ! dpkg --status "${runtime_dependency_pkgs[@]}" &>/dev/null; then
                runtime_dependency_packages_missing=true
            fi
        ;;
        *)
            printf \
                '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                "${FUNCNAME[0]}" \
                "${distro_id}" \
                1>&2
            return 1
        ;;
    esac

    if test "${runtime_dependency_packages_missing}" == true; then
        printf \
            'Info: Installing the runtime dependency packages for the determine_url_download_filename function...\n'

        case "${distro_id}" in
            debian|ubuntu)
                if ! apt-get install -y "${runtime_dependency_pkgs[@]}"; then
                    printf \
                        'Error: Unable to install the runtime dependency packages for the determine_url_download_filename function.\n' \
                        1>&2
                    return 2
                fi
            ;;
            *)
                printf \
                    '%s: Error: Operating system distribution(ID=%s) not supported.\n' \
                    "${FUNCNAME[0]}" \
                    "${distro_id}" \
                    1>&2
                return 1
            ;;
        esac
    fi
}

# Determine the actual download filename from the given URL, if the
# remote server does not hint the download filename, determine it from
# the URL or fail if the URL does not look like containing the download
# filename
#
# Standard output: Determined filename
# Return values:
#
# * 0 - Success
# * 1 - Prerequisite error
# * 2 - Generic error
determine_url_download_filename(){
    local download_url="${1}"; shift

    if ! determine_url_download_filename_ensure_deps; then
        printf \
            'Error: Unable to ensure runtime dependencies for the "%s" function.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local curl_response
    local -a curl_opts=(
        # Only fetch the response header
        --head

        # Follow URL redirection instructed by the remote server
        --location

        # Return non-zero exit status when HTTP error occurs
        --fail

        # Do not show progress meter but keep error messages
        --silent
        --show-error
    )
    if ! curl_response="$(curl "${curl_opts[@]}" "${download_url}")"; then
        printf \
            '%s: Error: Received an HTTP client error while trying to access the download URL "%s".\n' \
            "${FUNCNAME[0]}" \
            "${download_url}" \
            1>&2
        return 2
    fi

    local download_filename
    local content_diposition_response_header
    local -a grep_opts=(
        # Match without case-sensitivity(HTTP header may be in
        # different case
        --ignore-case

        # Use ERE instead of BRE which is more consistent with other
        # regexes
        --extended-regexp
    )
    local regex_content_disposition_header='^Content-Disposition:[[:space:]]+attachment;[[:space:]]+filename='
    if ! content_diposition_response_header="$(
        grep \
            "${grep_opts[@]}" \
            "${regex_content_disposition_header}" \
            <<<"${curl_response}"
        )"; then

        local regex_url_with_trailing_slash='/$'
        # Remote server doesn't indicate the downloaded filename, guess
        # it via the download URL
        if [[ "${download_url}" =~ ${regex_url_with_trailing_slash} ]]; then
            # Doesn't seemed to be a proper filename URL, error out
            printf \
                '%s: Error: The download URL(%s) does not seem to contain a download filename.\n' \
                "${FUNCNAME[0]}" \
                "${download_url}" \
                1>&2
            return 2
        fi

        # Stripping out the query string
        local download_url_without_query_string="${download_url%%\?*}"

        # Assuming the last path component of the download URL is the filename
        download_filename="${download_url_without_query_string##*/}"
    else
        # Stripping out trailing carriage return character
        content_diposition_response_header="${content_diposition_response_header%$'\r'}"

        download_filename="${content_diposition_response_header##*=}"
    fi

    printf '%s' "${download_filename}"
}

# Operations done when the program is terminating
trap_exit(){
    if test -v temp_dir \
        && test -e "${temp_dir}" \
        && test "${TESSERACT_ORANGE_DEBUG}" == false; then
        if ! rm -rf "${temp_dir}"; then
            printf \
                'Warning: Unable to clean up the temporary directory.\n' \
                1>&2
        fi
    fi

    if test "${TESSERACT_ORANGE_DEBUG}" == true; then
        printf \
            'DEBUG: Temporary directory for debugging: %s.\n' \
            "${temp_dir}" \
            1>&2
    fi
}

set \
    -o errexit \
    -o errtrace \
    -o nounset

required_commands=(
    realpath

    # Used in EXIT trap
    rm
)
flag_dependency_check_failed=false
for required_command in "${required_commands[@]}"; do
    if ! command -v "${required_command}" >/dev/null; then
        flag_dependency_check_failed=true
        printf \
            'Error: Unable to locate the "%s" command in the command search PATHs.\n' \
            "${required_command}" \
            1>&2
    fi
done
if test "${flag_dependency_check_failed}" == true; then
    printf \
        'Error: Dependency check failed, please check your installation.\n' \
        1>&2
fi

if ! trap trap_exit EXIT; then
    printf \
        'Error: Unable to set the EXIT trap.\n' \
        1>&2
    exit 2
fi

if test -v BASH_SOURCE; then
    # Convenience variables
    # shellcheck disable=SC2034
    {
        script="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
        )"
        script_dir="${script%/*}"
        script_filename="${script##*/}"
        script_name="${script_filename%%.*}"
    }
fi

# NOTE: This variable must in global scope in order the EXIT trap to
# work
temp_dir=

init
