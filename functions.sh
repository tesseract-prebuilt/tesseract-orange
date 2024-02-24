# shellcheck shell=bash
# Common functions
#
# Copyright 2024 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

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

    if test -v CI; then
        printf \
            'Info: CI environment detected, will not attempt to change the software sources.\n'
    else
        local -a mirror_patch_dependency_pkgs=(
            # For sending HTTP request to third-party IP address lookup
            # services
            curl

            # For parsing IP address lookup response
            grep

            # For patching APT software source definition list
            sed
        )
        if ! dpkg --status "${mirror_patch_dependency_pkgs[@]}" &>/dev/null; then
            printf \
                'Info: Installing the runtime dependencies packages for the mirror patching functionality...\n'
            if ! apt-get install -y "${mirror_patch_dependency_pkgs[@]}"; then
                printf \
                    'Error: Unable to install the runtime dependencies packages for the mirror patching functionality.\n' \
                    1>&2
                return 2
            fi
        fi

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
                    'Info: Local region code determined to be "%s".\n' \
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

# Determine the operating system distribution version of the current
# system
# Standard output: Result operating system distribution identifier
#
# Return values:
#
# * 0: OS identifier found
# * 1: Prerequisite not met
# * 2: Generic error
get_distro_version(){
    local operating_system_information_file=/etc/os-release

    # shellcheck source=/etc/os-release
    if ! source "${operating_system_information_file}"; then
        printf \
            '%s: Error: Unable to load the operating system information file.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -v VERSION_ID; then
        printf \
            'Error: The VERSION_ID variable assignment not found from the operating system information file(%s).\n' \
            "${operating_system_information_file}" \
            1>&2
        return 2
    fi

    printf '%s' "${VERSION_ID}"
}
