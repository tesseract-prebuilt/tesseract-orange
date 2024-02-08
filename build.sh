#!/usr/bin/env bash
# Build optimized Tesseract OCR engine from source
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

init(){
    if ! check_runtime_parameters; then
        printf \
            'Error: The runtime parameter check has failed.\n' \
            1>&2
        exit 1
    fi

    print_progress \
        'Operation completed without errors.'
}

# print progress report message with additional styling
print_progress(){
    local progress_msg="${1}"; shift

    local separator_string=
    local -i separator_length

    # NOTE: COLUMNS shell variable is not available in
    # non-noninteractive shell
    # FIXME: This calculation is not correct for double-width characters
    # (e.g. 中文)
    # https://www.reddit.com/r/bash/comments/gynqa0/how_to_determine_character_width_for_special/
    separator_length="${#progress_msg}"

    # Reduce costly I/O operations
    local -i separator_blocks separator_remain_units
    separator_blocks="$(( separator_length / 10 ))"
    separator_remain_units="$(( separator_length % 10 ))"

    local -i i j
    for ((i = 0; i < separator_blocks; i = i + 1)); do
        separator_string+='=========='
    done
    for ((j = 0; j < separator_remain_units; j = j + 1)); do
        separator_string+='='
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

init
