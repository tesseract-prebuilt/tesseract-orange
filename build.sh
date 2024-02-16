#!/usr/bin/env bash
# Build optimized Tesseract OCR engine from source
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
TESSERACT_VERSION="${TESSERACT_VERSION:-latest}"

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

    if ! prepare_software_sources; then
        printf \
            'Error: Unable to prepare the software sources.\n' \
            1>&2
        exit 2
    fi

    local cache_dir="${script_dir}/cache"
    if ! test -d "${cache_dir}"; then
        print_progress 'Creating the cache directory...'
        if ! mkdir "${cache_dir}"; then
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

    print_progress 'Determining which Tesseract version to build...'
    local tesseract_version
    if test "${TESSERACT_VERSION}" == latest; then
        if ! query_latest_tesseract_version_ensure_dependencies; then
            printf \
                'Error: Unable to ensure the runtime dependencies for the query_latest_tesseract_version function.\n' \
                1>&2
            exit 2
        fi

        tesseract_version="$(query_latest_tesseract_version)"
        printf \
            'Info: Will build current latest version of Tesseract("%s") determined from the GitHub References API response.\n' \
            "${tesseract_version}"
    else
        tesseract_version="${TESSERACT_VERSION}"
        printf \
            'Info: Will build version "%s" of Tesseract specified from the TESSERACT_VERSION environment variable.\n' \
            "${tesseract_version}"
    fi

    print_progress \
        'Operation completed without errors.'
}

query_latest_tesseract_version_ensure_dependencies(){
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
# to "auto") by calling the GitHub APIs
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
    printf 'Info: Checking running user...\n'
    if test "${EUID}" -ne 0; then
        printf \
            'Error: This program requires to be run as the superuser(root).\n' \
            1>&2
        return 2
    fi
}

prepare_software_sources(){
    print_progress 'Preparing software sources...'

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

    # Silence warnings regarding unavailable debconf frontends
    export DEBIAN_FRONTEND=noninteractive

    base_runtime_dependency_pkgs=(
        curl
    )
    if ! dpkg -s "${base_runtime_dependency_pkgs[@]}" &>/dev/null; then
        printf \
            'Info: Installing base runtime dependency packages...\n'
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

    if ! test -v CI; then
        printf \
            'Info: Detecting local region code...\n'
        curl_opts=(
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
            grep_opts=(
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
            curl_opts=(
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

# Operations done when the program is terminating
trap_exit(){
    if test -v temp_dir && test -e "${temp_dir}"; then
        if ! rm -rf "${temp_dir}"; then
            printf \
                'Warning: Unable to clean up the temporary directory.\n' \
                1>&2
        fi
    fi
}
if ! trap trap_exit EXIT; then
    printf \
        'Error: Unable to set the EXIT trap.\n' \
        1>&2
    exit 2
fi

set \
    -o errexit \
    -o errtrace \
    -o nounset

required_commands=(
    realpath
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