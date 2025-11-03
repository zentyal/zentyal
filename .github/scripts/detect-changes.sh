#!/usr/bin/env bash

# Version 0.0.1

# This script detects modified modules and checks if they have an updated ChangeLog.

set -euo pipefail
IFS=$'\n\t'


###
## Functions
###

function usage() {
    echo "Usage: $0 <argument>"
    echo
    echo "Arguments:"
    echo "  changed-modules     List unique modules that have changed."
    echo "  missing-changelogs  List modules with changes but missing ChangeLog updates."
    echo
    echo "Environment:"
    echo "  ALL_CHANGED_FILES   Must contain the list of changed files (space or newline separated)."
    exit 1
}


function get_changed_modules() {
    local files="$1"
    local modules=()

    # Read each file (space or newline)
    while read -r file; do
        if [[ $file =~ ^(extra|main)/([^/]+)/ ]]; then
            local module="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
            modules+=("$module")
        fi
    done <<< "${files// /$'\n'}"  # <-- convert spaces to newlines

    mapfile -t unique_modules < <(printf "%s\n" "${modules[@]}" | sort -u)
    echo "${unique_modules[@]}"
}


function get_missing_changelogs() {
    local files="$1"
    local missing=()

    # Get modules, one per line
    local modules
    modules=$(get_changed_modules "$files")

    # Convert list of files to line format
    local file_list
    file_list=$(echo "${files// /$'\n'}")

    # Read module line by line to avoid concatenations
    while read -r mod; do
        [[ -z "$mod" ]] && continue
        if ! grep -qx "${mod}/ChangeLog" <<< "${file_list}"; then
            missing+=("$mod")
        fi
    done <<< "${modules// /$'\n'}"

    echo "${missing[@]}"
}


function export_for_github() {
    local key="$1"
    local value="$2"

    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "${key}=${value}" >> "$GITHUB_OUTPUT"
    fi
}


###
## Main script
###

if [[ $# -lt 1 ]]; then
    usage
fi

argument=${1}
ALL_CHANGED_FILES="${ALL_CHANGED_FILES:-}"

if [[ -z "${ALL_CHANGED_FILES}" ]]; then
    echo "Error: ALL_CHANGED_FILES variable is empty or not set."
    exit 1
fi

case "$argument" in
    changed-modules)
        echo "Detecting changed modules..."
        changed=$(get_changed_modules "${ALL_CHANGED_FILES}")
        echo "Changed modules: ${changed}"
        export_for_github "changed_modules" "${changed}"
        ;;
    missing-changelogs)
        echo "Checking for missing ChangeLogs..."
        missing=$(get_missing_changelogs "${ALL_CHANGED_FILES}")
        echo "Modules missing ChangeLogs: ${missing}"
        export_for_github "missing_changelog_modules" "${missing}"
        ;;
    *)
        echo "Error: Unknown argument '$argument'"
        usage
        ;;
esac
