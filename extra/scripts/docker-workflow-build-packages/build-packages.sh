#!/usr/bin/env bash
# =============================================================================
# Zentyal Package Builder
# Version: 0.0.2
#
# This script clones a Zentyal repo, builds selected modules, and uploads
# generated packages to Amazon S3.
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
DIR_BASE="/srv"
TMP_DIR="/tmp/packages"
REPO_NAME="zentyal"

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0

Environment variables required:
  REPO             Git repository URL
  BRANCH           Branch name to checkout
  MODULES          List of modules to build (space separated)
  S3_BUCKET_DEST   S3 bucket to upload packages

Example:
  REPO="https://github.com/zentyal/zentyal.git"
  BRANCH="8.0"
  MODULES="main/core extra/zenbuntu-core"
  S3_BUCKET_DEST="my-zentyal-packages"
EOF
    exit 1
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

check_env() {
    log "Checking environment variables..."
    local missing=0
    for var in REPO BRANCH MODULES S3_BUCKET_DEST; do
        if [[ -z "${!var:-}" ]]; then
            warn "Missing required variable: $var"
            usage
        fi
    done
}


prepare_environment() {
    log "Preparing environment..."
    mkdir -pv "$TMP_DIR"
    cd "$DIR_BASE"
}


clone_repository() {
    log "Cloning repository..."
    git clone --single-branch --branch "$BRANCH" "$REPO"
    cd "$REPO_NAME"
    log "Repository cloned successfully. Current path: $(pwd)"
    git status
}


build_module() {
    local module=$1
    log ">>> Building module: $module"

    if [[ ! -d $module ]]; then
        warn "Module directory $module does not exist. Skipping."
        return
    fi

    pushd "$module" >/dev/null

    if ! command -v zentyal-package &>/dev/null; then
        error "zentyal-package command not found. Please install it in the image."
    fi

    zentyal-package

    # Copy relevant files
    find debs-ppa/ -type f \( -name "*.deb" -o -name "*.dsc" -o -name "*.xz" -o -name "*.gz" \) \
        -print0 | xargs -0 cp -vt "$TMP_DIR"

    popd >/dev/null
    log ">>> Finished building module: $module"
}


build_all_modules() {
    log "Building all modules..."
    while IFS= read -r module; do
        build_module "$module"
    done < <(echo "$MODULES" | tr ' ' '\n')
}


clean_s3_bucket() {
    log "Cleaning S3 bucket: s3://$S3_BUCKET_DEST/"
    aws s3 rm "s3://$S3_BUCKET_DEST/" --recursive
    log "S3 bucket cleaned."
}


upload_to_s3() {
    log "Listing generated packages:"
    ls -lh "$TMP_DIR" || warn "No packages found."

    log "Uploading packages to Amazon S3..."
    cd ${TMP_DIR}
    aws s3 sync ./ "s3://$S3_BUCKET_DEST/" --delete

    log "Packages uploaded successfully to s3://$S3_BUCKET_DEST/"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    log "=== Starting Zentyal package build process ==="
    log "Repository: $REPO"
    log "Branch:     $BRANCH"
    log "Modules:    $MODULES"
    log "S3 Bucket:  $S3_BUCKET_DEST"

    check_env
    prepare_environment
    clone_repository
    build_all_modules
    clean_s3_bucket
    upload_to_s3

    log "=== Build process completed successfully ==="
}

main "$@"
