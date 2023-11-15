#!/usr/bin/env bash
# Build optimized Tesseract OCR engine
#
# Copyright 2023 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

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
