#!/usr/bin/env bash
# Install specified Tesseract traineddata to the product
#
# Copyright 2024 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

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
        'Tesseract Orange Tesseract traineddata installer' \
        =

    print_progress \
        'Checking runtime parameters...'
    printf \
        'Checking running user...\n'
    if ! check_running_user; then
        printf \
            'Error: The running user check has failed.\n' \
            1>&2
        exit 1
    fi

    printf \
        'Info: Checking program arguments...\n'
    if test "${#script_args[@]}" -le 1; then
        printf \
            'Usage: "%s" [fast|best|legacy] [_lang_|_script_]...\n' \
            "${script_basecommand}"
        exit 0
    fi

    local traineddata_set="${script_args[0]}"; shift_array script_args

    if ! validate_traineddata_set "${traineddata_set}"; then
        printf \
            'Error: Trainneddata set validation has failed.\n' \
            1>&2
        exit 1
    fi

    local -a lang_or_scripts=("${script_args[@]}")

    print_progress \
        'Detecting operating system distribution information...'
    printf \
        'Info: Querying the operating system distribution identifier...\n'
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            'Error: Unable to query the operating system distribution identifier.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: The operating system distribution identifier of this system is "%s".\n' \
        "${distro_id}"

    if ! refresh_package_manager_local_cache; then
        printf \
            "Error: Unable to refresh the software package management system's local data cache.\\n" \
            1>&2
        exit 2
    fi

    local -a installer_dependency_pkgs=(
        # For file manipulation, string manipulation, ...etc.
        coreutils

        # For downloading the traineddata files
        curl

        # For parsing the HTTP response headers to determine the remote
        # filesize
        grep
    )
    if ! check_distro_packages_installed "${installer_dependency_pkgs[@]}"; then
        print_progress \
            'Ensuring the installer dependencies...'

        printf \
            'Info: Installing the installer dependencies packages...\n'
        if ! install_distro_packages "${installer_dependency_pkgs[@]}"; then
            printf \
                'Error: Unable to install the installer dependencies packages.\n' \
                1>&2
            exit 2
        fi
    fi

    print_progress \
        'Determining operation timestamp...'
    if ! operation_timestamp="$(date +%Y%m%d-%H%M%S)"; then
        printf \
            'Error: Unable to query the current timestamp.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: Operation timestamp determined to be "%s".\n' \
        "${operation_timestamp}"

    printf \
        'Info: Checking Tesseract data directory path...\n'
    local tessdata_dir
    tesseract_orange_tessdata_dir="${script_dir}/share/tessdata"
    if test -v TESSDATA_DIR; then
        # Custom environment variable for easier management of data files
        # Not a mispelling
        # shellcheck disable=SC2153
        tessdata_dir="${TESSDATA_DIR}"
    elif test -v TESSDATA_PREFIX; then
        # TESSDATA_PREFIX environment variable should be set to the
        # parent directory of “tessdata” directory
        tessdata_dir="${TESSDATA_PREFIX}/tessdata"
    elif test -e "${tesseract_orange_tessdata_dir}"; then
        tessdata_dir="${tesseract_orange_tessdata_dir}"
    else
        printf \
            'Error: Unable to determine the Tesseract data directory path.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: The Tesseract data directory path determined to be "%s".\n' \
        "${tessdata_dir}"

    if ! test -e "${tessdata_dir}"; then
        printf \
            'Info: Creating the Tessearct data directory...\n'
        local -a mkdir_opts=(
            --parents
            --verbose
        )
        if ! mkdir "${mkdir_opts[@]}" "${tessdata_dir}"; then
            printf \
                'Error: Unable to create the Tessearct data directory...\n' \
                1>&2
            exit 2
        fi
    fi

    print_progress \
        'Analysing the specified languages and scripts...'
    local -a languages=() scripts=()
    for lang_or_script in "${lang_or_scripts[@]}"; do
        # If first character is lowercase, it is a language specification
        if test "${lang_or_script^}" != "${lang_or_script}"; then
            languages+=("${lang_or_script}")
        else
            scripts+=("${lang_or_script}")
        fi
    done

    if test "${#languages[@]}" -ne 0; then
        printf \
            'Info: Will install the following languages:\n\n'
        for language in "${languages[@]}"; do
            printf '* %s\n' "${language}"
        done
    fi

    if test "${#languages[@]}" -ne 0 \
        && test "${#scripts[@]}" -ne 0; then
        # Linebreak for proper output formatting
        printf '\n'
    fi

    if test "${#scripts[@]}" -ne 0; then
        printf 'Info: Will install the following scripts:\n\n'
        for script in "${scripts[@]}"; do
            printf '* %s\n' "${script}"
        done
    fi

    if test "${#languages[@]}" -gt 0; then
        print_progress \
            'Downloading the specified language traineddata...'
        for language in "${languages[@]}"; do
            download_tesseract_traineddata \
                "${language}" \
                "${traineddata_set}" \
                language \
                "${tessdata_dir}"
        done
    fi

    if test "${#scripts[@]}" -gt 0; then
        print_progress \
            'Installing the specified script traineddata...'
        for script in "${scripts[@]}"; do
            download_tesseract_traineddata \
                "${script}" \
                "${traineddata_set}" \
                script \
                "${tessdata_dir}"
        done
    fi

    print_progress \
        'Operation completed without errors.'
}

validate_traineddata_set(){
    local traineddata_set="${1}"; shift

    local regex_traineddata_sets='^(fast|best|legacy)$'

    if ! [[ "${traineddata_set}" =~ ${regex_traineddata_sets} ]]; then
        printf \
            'Error: Invalid traineddata set specified(%s), should be either "fast", "best", or "legacy".\n' \
            "${traineddata_set}" \
            1>&2
        return 2
    fi
}

validate_traineddata_type(){
    local traineddata_type="${1}"; shift

    local regex_traineddata_types='^(language|script)$'
    if ! [[ "${traineddata_type}" =~ ${regex_traineddata_types} ]]; then
        printf \
            'Error: Invalid traineddata type specified(%s), should be either "language" or "script".\n' \
            "${traineddata_type}" \
            1>&2
        return 2
    fi
}

# Download specified Tesseract traineddata from the Internet
download_tesseract_traineddata(){
    local langauge_or_script="${1}"; shift
    local traineddata_set="${1}"; shift
    local traineddata_type="${1}"; shift
    local tessdata_dir="${1}"; shift

    if ! validate_traineddata_set "${traineddata_set}"; then
        printf \
            '%s: Error: Trainneddata set validation has failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! validate_traineddata_type "${traineddata_type}"; then
        printf \
            '%s: Error: Trainneddata type validation has failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local download_url
    case "${traineddata_type}" in
        language)
            printf \
                'Info: Determining the download URL of the "%s" language of the "%s" traineddata set...\n' \
                "${langauge_or_script}" \
                "${traineddata_set}"
            case "${traineddata_set}" in
                best)
                    download_url="https://github.com/tesseract-ocr/tessdata_best/raw/main/${langauge_or_script}.traineddata"
                ;;
                fast)
                    download_url="https://github.com/tesseract-ocr/tessdata_fast/raw/main/${langauge_or_script}.traineddata"
                ;;
                legacy)
                    download_url="https://github.com/tesseract-ocr/tessdata/raw/main/${langauge_or_script}.traineddata"
                ;;
                *)
                    printf \
                        'Error: Traineddata set "%s" is not supported.\n' \
                        "${traineddata_set}" \
                        1>&2
                    return 1
                ;;
            esac
            printf \
                'Info: The download URL for the "%s" language of the "%s" traineddata set determined to be "%s".\n' \
                "${langauge_or_script}" \
                "${traineddata_set}" \
                "${download_url}"
        ;;
        script)
            printf \
                'Info: Determining the download URL of the "%s" script of the "%s" traineddata set...\n' \
                "${langauge_or_script}" \
                "${traineddata_set}"s
            case "${traineddata_set}" in
                best)
                    download_url="https://github.com/tesseract-ocr/tessdata_best/raw/main/script/${langauge_or_script}.traineddata"
                ;;
                fast)
                    download_url="https://github.com/tesseract-ocr/tessdata_fast/raw/main/script/${langauge_or_script}.traineddata"
                ;;
                legacy)
                    download_url="https://github.com/tesseract-ocr/tessdata/raw/main/script/${langauge_or_script}.traineddata"
                ;;
                *)
                    printf \
                        'Error: Traineddata set "%s" is not supported.\n' \
                        "${traineddata_set}" \
                        1>&2
                    return 1
                ;;
            esac
            printf \
                'Info: The download URL for the "%s" script of the "%s" traineddata set determined to be "%s".\n' \
                "${langauge_or_script}" \
                "${traineddata_set}" \
                "${download_url}"
        ;;
        *)
            printf \
                'Error: Traineddata type "%s" is not supported.\n' \
                "${traineddata_type}" \
                1>&2
            return 1
        ;;
    esac

    printf \
        'Info: Checking whether the "%s" traineddata file is already existed locally...\n' \
        "${langauge_or_script}"
    local local_traineddata_file
    case "${traineddata_type}" in
        language)
            local_traineddata_file="${tessdata_dir}/${langauge_or_script}.traineddata"
        ;;
        script)
            local_traineddata_file="${tessdata_dir}/script/${langauge_or_script}.traineddata"
        ;;
        *)
            printf \
                'Error: Traineddata set "%s" is not supported.\n' \
                "${traineddata_set}" \
                1>&2
            return 1
        ;;
    esac

    local flag_local_traineddata_file_exists
    if test -e "${local_traineddata_file}"; then
        printf \
            'Info: The "%s" traineddata file is already existed locally.\n' \
            "${langauge_or_script}"
        flag_local_traineddata_file_exists=true
    else
        printf \
            'Info: The "%s" traineddata file does not existed locally.\n' \
            "${langauge_or_script}"
        flag_local_traineddata_file_exists=false
    fi

    if test "${flag_local_traineddata_file_exists}" == true; then
        printf \
            'Info: Checking whether the local traineddata file is outdated...\n'
        local flag_local_traineddata_file_is_outdated=false

        printf \
            'Info: Checking the local filesize of the "%s" traineddata...\n' \
            "${langauge_or_script}"
        local -a stat_opts=(
            # Customize output to only filesize in bytes
            --format='%s'
        )
        if ! local_traineddata_filesize="$(
            stat "${stat_opts[@]}" "${local_traineddata_file}"
            )"; then
            printf \
                'Error: Unable to query the filesize of the "%s" local traineddata file.\n' \
                "${local_traineddata_file}" \
                1>&2
            exit 2
        fi
        printf \
            'Info: The filesize of the "%s" local traineddata file determined to be "%s".\n' \
            "${local_traineddata_file}" \
            "${local_traineddata_filesize}"

        printf \
            'Info: Checking the remote filesize of the "%s" traineddata...\n' \
            "${langauge_or_script}"
        local -a curl_opts=(
            --head
            --location
            --silent
            --show-error
        )
        local remote_traineddata_filesize_raw
        if ! remote_traineddata_filesize_raw="$(
            curl "${curl_opts[@]}" "${download_url}"
            )"; then
            printf \
                'Error: Unable to request the remote filesize information of the "%s" trainneddata.\n' \
                "${langauge_or_script}" \
                1>&2
            exit 2
        fi

        # curl --head output contains CRLF lineendings, sanitize them
        local -a tr_opts=(
            --delete
        )
        local remote_traineddata_filesize_raw_without_cr
        if ! remote_traineddata_filesize_raw_without_cr="$(
            tr "${tr_opts[@]}" '\r' \
                <<<"${remote_traineddata_filesize_raw}"
            )"; then
            printf \
                'Error: Unable to strip the CR lineendings from the curl response headers.\n' \
                1>&2
            exit 2
        fi

        local -a grep_opts=(
            # We would like to use the lookbehind syntax
            --perl-regexp

            # Match case insensitively
            --ignore-case

            # Only print part that matches the expression, not the
            # entire line
            --only-matching
        )
        local regex_content_length_header_values='(?<=^content-length: ).*'
        local remote_traineddata_filesize_raw_content_lengths_raw
        if ! remote_traineddata_filesize_raw_content_lengths_raw="$(
            grep \
                "${grep_opts[@]}" \
                "${regex_content_length_header_values}" \
                <<<"${remote_traineddata_filesize_raw_without_cr}"
            )"; then
            printf \
                'Error: Unable to match the content-length HTTP response header values from the remote traineddata filesize HTTP response.\n' \
                1>&2
            exit 2
        fi

        # The last value is the real filesize
        local -a tail_opts=(
            --lines=1
        )
        local remote_traineddata_filesize
        if ! remote_traineddata_filesize="$(
            tail "${tail_opts[@]}" <<<"${remote_traineddata_filesize_raw_content_lengths_raw}"
            )"; then
            printf \
                'Error: Unable to parse out the remote traineddata filesize from the HTTP response headers.\n' \
                1>&2
            exit 2
        fi

        local regex_non_negative_integers='^(0|[1-9][0-9]*)$'
        if ! [[ "${remote_traineddata_filesize}" =~ ${regex_non_negative_integers} ]]; then
            printf \
                'Error: Invalid remote traineddata filesize "%s" is retrieved.\n' \
                "${remote_traineddata_filesize}" \
                1>&2
            exit 2
        fi

        printf \
            'Info: The remote filesize of the "%s" traineddata determined to be "%s"...\n' \
            "${langauge_or_script}" \
            "${remote_traineddata_filesize}"

        if test "${local_traineddata_filesize}" -ne "${remote_traineddata_filesize}"; then
            flag_local_traineddata_file_is_outdated=true
            printf \
                'Info: The local trainneddata file seems to be outdated, moving...\n'
            backuped_local_traineddata_file="${local_traineddata_file}.old.${operation_timestamp}"
            local -a mv_opts=(
                --verbose
            )
            if ! mv \
                "${mv_opts[@]}" \
                "${local_traineddata_file}" \
                "${backuped_local_traineddata_file}"; then
                printf \
                    'Error: Unable to move the old local traineddata file.\n' \
                    1>&2
                exit 2
            fi
        else
            printf \
                'Info: The local trainneddata file is up-to-date, skipping...\n'
        fi
    fi

    if test "${flag_local_traineddata_file_exists}" == false \
        || test "${flag_local_traineddata_file_is_outdated}" == true; then
        local local_traineddata_file_dir="${local_traineddata_file%/*}"

        if ! test -e "${local_traineddata_file_dir}"; then
            printf \
                'Info: Creating the "%s" local traineddata file directory...\n' \
                "${local_traineddata_file_dir}"
            local -a mkdir_opts=(
                --parents
                --verbose
            )
            if ! mkdir "${mkdir_opts[@]}" "${local_traineddata_file_dir}"; then
                printf \
                    'Error: Unable to create the "%s" local traineddata file directory...\n' \
                    "${local_traineddata_file_dir}" \
                    1>&2
                exit 2
            fi
        fi

        # COMPATIBILITY: For CentOS 7 which doesn't support the
        # --output-dir curl command-line option
        printf \
            'Info: Changing the working directory to the local traineddata file directory(%s)...\n' \
            "${local_traineddata_file_dir}"
        if ! cd "${local_traineddata_file_dir}"; then
            printf \
                'Error: Unable to change the working directory to the local traineddata file directory(%s)...\n' \
                "${local_traineddata_file_dir}" \
                1>&2
            exit 2
        fi

        printf \
            'Info: Downloading the "%s" trainneddata of the "%s" set...\n' \
            "${langauge_or_script}" "${traineddata_set}"

        local -a curl_opts=(
            --location
            --remote-name
            --remote-header-name

            --fail
        )
        if ! curl "${curl_opts[@]}" "${download_url}"; then
            printf \
                'Error: Unable to download the "%s" trainneddata of the "%s" set...\n' \
                "${langauge_or_script}" "${traineddata_set}" \
                1>&2
            exit 2
        fi
    fi
}

set_opts=(
    # Terminate script execution when an unhandled error occurs
    -o errexit
    -o errtrace

    # Terminate script execution when an unset parameter variable is
    # referenced
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to set the defensive interpreter behavior.\n' \
        1>&2
    exit 1
fi

required_commands=(
    realpath

    # For determining the operation timestamp
    date

    # For querying the username of the running user
    whoami
)
flag_dependency_check_failed=false
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null; then
        flag_dependency_check_failed=true
        printf \
            'Error: Unable to locate the "%s" command in the command search PATHs.\n' \
            "${command}" \
            1>&2
    fi
done
if test "${flag_dependency_check_failed}" == true; then
    printf \
        'Error: Dependency check failed, please check your installation.\n' \
        1>&2
    exit 1
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
        if test "${#}" -eq 0; then
            script_args=()
        else
            script_args=("${@}")
        fi
        script_basecommand="${0}"
    }
fi

init
