#!/usr/bin/env bash
# Build optimized Tesseract OCR engine from source
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
TESSERACT_VERSION="${TESSERACT_VERSION:-latest}"
TESSERACT_SOURCE_ARCHIVE_URL="${TESSERACT_SOURCE_ARCHIVE_URL:-"https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESSERACT_VERSION}.tar.gz"}"
TESSERACT_ORANGE_DEBUG="${TESSERACT_ORANGE_DEBUG:-false}"

LEPTONICA_VERSION="${LEPTONICA_VERSION:-latest}"
LEPTONICA_SOURCE_ARCHIVE_URL="${LEPTONICA_SOURCE_ARCHIVE_URL:-"https://github.com/DanBloomberg/leptonica/releases/download/${LEPTONICA_VERSION}/leptonica-${LEPTONICA_VERSION}.tar.gz"}"

init(){
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

    print_progress \
        'Operation completed without errors.'
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

# print progress report message with additional styling
#
# Positional parameters:
#
# progress_msg: Progress report message text
# separator_char: Character used in the separator
print_progress(){
    local progress_msg="${1}"; shift
    local separator_char
    if test "${#}" -gt 0; then
        if test "${#1}" -ne 1; then
            printf -- \
                '%s: FATAL: The separator_char positional parameter only accept a single character as its argument.\n' \
                "${FUNCNAME[0]}" \
                1>&2
            exit 99
        fi
        separator_char="${1}"; shift
    else
        separator_char=-
    fi

    local separator_string=
    local -i separator_length

    # NOTE: COLUMNS shell variable is not available in
    # non-noninteractive shell
    # FIXME: This calculation is not correct for double-width characters
    # (e.g. 中文)
    # https://www.reddit.com/r/bash/comments/gynqa0/how_to_determine_character_width_for_special/
    separator_length="${#progress_msg}"

    # Reduce costly I/O operations
    local separator_block_string=
    local -i \
        separator_block_length=10 \
        separator_blocks \
        separator_remain_units
    separator_blocks="$(( separator_length / separator_block_length ))"
    separator_remain_units="$(( separator_length % separator_block_length ))"

    local -i i j k
    for ((i = 0; i < separator_block_length; i = i + 1)); do
        separator_block_string+="${separator_char}"
    done
    for ((j = 0; j < separator_blocks; j = j + 1)); do
        separator_string+="${separator_block_string}"
    done
    for ((k = 0; k < separator_remain_units; k = k + 1)); do
        separator_string+="${separator_char}"
    done

    printf \
        '\n%s\n%s\n%s\n' \
        "${separator_string}" \
        "${progress_msg}" \
        "${separator_string}"
}

check_runtime_parameters(){
    print_progress 'Checking the runtime parameters of this program...'

    local -a required_commands=(
        # For querying the current username
        whoami
    )
    local required_command_check_failed=false
    for command in "${required_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                '%s: Error: This function requires the "%s" command to be available in your command search PATHs.\n' \
                "${FUNCNAME[0]}" \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            '%s: Error: Required command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    printf 'Info: Checking running user...\n'
    if test "${EUID}" -ne 0; then
        printf \
            'Error: This program requires to be run as the superuser(root).\n' \
            1>&2
        return 2
    else
        local running_user
        if ! running_user="$(whoami)"; then
            printf \
                "Error: Unable to query the runnning user's username.\\n" \
                1>&2
            return 2
        fi
        printf \
            'Info: The running user is acceptible(%s).\n' \
            "${running_user}"
    fi
}

# Query the operating system distribution identifier
#
# Standard output: Result operating system distribution identifier
# Return values:
#
# * 0: OS identifier found
# * 1: Prerequisite not met
# * 2: Generic error
get_distro_identifier(){
    local operating_system_information_file=/etc/os-release

    # shellcheck source=/etc/os-release
    if ! source "${operating_system_information_file}"; then
        printf \
            '%s: Error: Unable to load the operating system information file.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -v ID; then
        printf \
            'Error: The ID variable assignment not found from the operating system information file(%s).\n' \
            "${operating_system_information_file}" \
            1>&2
        return 2
    fi

    printf '%s' "${ID}"
}

# Check the availability of the package manager external commands
#
# Return values:
#
# * 0: Check passed
# * 1: Prerequisite not met
# * 2: Generic error
check_package_manager_commands(){
    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            'Error: Unable to query the operating system distribution identifier.\n' \
            1>&2
        return 2
    fi

    local -a required_package_manager_commands
    case "${distro_id}" in
        debian|ubuntu)
            required_package_manager_commands=(
                dpkg
                apt-get
            )
        ;;
        *)
            printf \
                'Error: This operating system(ID=%s) is currently not supported.\n' \
                "${ID}" \
                1>&2
            return 2
        ;;
    esac

    local required_command_check_failed=false
    for command in "${required_package_manager_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                'Error: The "%s" required package manager command is not available in your command search PATHs.\n' \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            'Error: Package manager command availability check failed.\n' \
            1>&2
        return 3
    fi
}

prepare_software_sources(){
    print_progress 'Preparing software sources...'

    local -a required_commands=(
        # For determining the current time
        date

        # For determining the APT local cache creation time
        stat
    )
    local required_command_check_failed=false
    for command in "${required_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                '%s: Error: This function requires the "%s" command to be available in your command search PATHs.\n' \
                "${FUNCNAME[0]}" \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            '%s: Error: Required command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! check_package_manager_commands; then
        printf \
            'Error: Package manager command check failed.\n' \
            1>&2
        return 1
    fi

    # Silence warnings regarding unavailable debconf frontends
    export DEBIAN_FRONTEND=noninteractive

    local apt_archive_cache_mtime_epoch
    if ! apt_archive_cache_mtime_epoch="$(
        stat \
            --format=%Y \
            /var/cache/apt/archives
        )"; then
        printf \
            'Error: Unable to query the modification time of the APT software sources cache directory.\n' \
            1>&2
        return 2
    fi

    local current_time_epoch
    if ! current_time_epoch="$(
        date +%s
        )"; then
        printf \
            'Error: Unable to query the current time.\n' \
            1>&2
        return 2
    fi

    if test "$((current_time_epoch - apt_archive_cache_mtime_epoch))" -ge 86400; then
        printf \
            'Info: Refreshing the APT local package cache...\n'
        if ! apt-get update; then
            printf \
                'Error: Unable to refresh the APT local package cache.\n' \
                1>&2
            return 2
        fi
    fi

    if ! test -v CI; then
        printf \
            'Info: Detecting local region code...\n'
        local -a curl_opts=(
            # Return non-zero exit status when HTTP error occurs
            --fail

            # Do not show progress meter but keep error messages
            --silent
            --show-error
        )
        if ! ip_reverse_lookup_service_response="$(
                curl \
                    "${curl_opts[@]}" \
                    https://ipinfo.io/json
            )"; then
            printf \
                'Warning: Unable to detect the local region code(IP address reverse lookup service not available), falling back to default.\n' \
                1>&2
            region_code=
        else
            local -a grep_opts=(
                --perl-regexp
                --only-matching
            )
            if ! region_code="$(
                grep \
                    "${grep_opts[@]}" \
                    '(?<="country": ")[[:alpha:]]+' \
                    <<<"${ip_reverse_lookup_service_response}"
                )"; then
                printf \
                    'Warning: Unable to query the local region code, falling back to default.\n' \
                    1>&2
                region_code=
            else
                printf \
                    'Info: Local region code determined to be "%s"\n' \
                    "${region_code}"
            fi
        fi

        if test -n "${region_code}"; then
            # The returned region code is capitalized, fixing it.
            region_code="${region_code,,*}"

            printf \
                'Info: Checking whether the local Ubuntu archive mirror exists...\n'
            local -a curl_opts=(
                # Return non-zero exit status when HTTP error occurs
                --fail

                # Do not show progress meter but keep error messages
                --silent
                --show-error
            )
            if ! \
                curl \
                    "${curl_opts[@]}" \
                    "http://${region_code}.archive.ubuntu.com" \
                    >/dev/null; then
                printf \
                    "Warning: The local Ubuntu archive mirror doesn't seem to exist, falling back to default...\\n"
                region_code=
            else
                printf \
                    'Info: The local Ubuntu archive mirror service seems to be available, using it.\n'
            fi
        fi

        if test -n "${region_code}" \
            && ! grep -q "${region_code}.archive.u" /etc/apt/sources.list; then
            printf \
                'Info: Switching to use the local APT software repository mirror...\n'
            if ! \
                sed \
                    --in-place \
                    "s@//archive.u@//${region_code}.archive.u@g" \
                    /etc/apt/sources.list; then
                printf \
                    'Error: Unable to switch to use the local APT software repository mirror.\n' \
                    1>&2
                return 2
            fi

            printf \
                'Info: Refreshing the local APT software archive cache...\n'
            if ! apt-get update; then
                printf \
                    'Error: Unable to refresh the local APT software archive cache.\n' \
                    1>&2
                return 2
            fi
        fi
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
