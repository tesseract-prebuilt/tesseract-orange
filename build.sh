#!/usr/bin/env bash
# Build optimized Tesseract OCR engine from source
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

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
        if ! mkdir "${cache_dir}"; then
            printf \
                'Error: Unable to create the cache directory.\n' \
                1>&2
            exit 2
        fi
    fi

    local operation_timestamp
    if ! operation_timestamp="$(date +%Y%m%d-%H%M%S)"; then
        printf \
            'Error: Unable to query the operation timestamp.\n' \
            1>&2
        exit 2
    fi

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
    fi

    print_progress \
        'Operation completed without errors.'
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
        wget
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
        wget_opts=(
            # Output to the standard output device
            --output-document=-

            # Don't output debug messages
            --quiet
        )
        if ! ip_reverse_lookup_service_response="$(
                wget \
                    "${wget_opts[@]}" \
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
            wget_opts=(
                # Output to the standard output device
                --output-document=-

                # Don't output debug messages
                --quiet
            )
            if ! \
                wget \
                    "${wget_opts[@]}" \
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
