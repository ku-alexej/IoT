#!/bin/bash
set -e

# ==============================
# COLORS
# ==============================

readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly WHITE="\033[1;37m"
readonly RESET="\033[0m"

# ==============================
# CONFIGURATION
# ==============================

readonly USERNAME="akurochk"
readonly EMAIL="akurochk@student.42.fr"

readonly GIT_USER="ku-alexej"
readonly GIT_DIR="akurochk-Inception-of-Things"

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_REPO="${HOME}/${GIT_DIR}"

# ==============================
# LOG FUNCTIONS
# ==============================

title() {
    local text=$1
    printf "\n${WHITE}>>> %s <<<${RESET}\n" "$text"
}

log_step() {
    local number=$1
    local text=$2
    printf "\n[%s/9] %s:\n" "$number" "$text"
}

status() {
    local name="$1"
    local status="$2"
    local color="$3"
    printf "     - %-10s : ${color}%s${RESET}\n" "$name" "$status"
}

log_success() {
    status "$1" "$2" "$GREEN"
}

log_warning() {
    status "$1" "$2" "$YELLOW"
}

# ==============================
# SETUPS
# ==============================

prepare_manifest() {

    log_warning "manifest" "cloning repository"
    rm -rf ${DIR_REPO}
    git clone "git@github.com:${GIT_USER}/${GIT_DIR}.git" "$DIR_REPO" >/dev/null 2>&1

    log_warning "manifest" "configuring local repository"
    cd "$DIR_REPO"
    git config --local user.name "$USERNAME"
    git config --local user.email "$EMAIL"
    cp "${DIR_SCRIPT}/../confs/01_deployment_v1.yaml" "${DIR_REPO}/deployment.yaml"

    git add deployment.yaml
    if ! git diff --cached --quiet; then
        log_warning "manifest" "committing changes"
        git commit -m "chore: update deployment manifest (v1)" >/dev/null 2>&1
        log_warning "manifest" "pushing changes"
        git push -u origin main >/dev/null 2>&1
    fi

    log_success "manifest" "v1 ready"
}

# ==============================
# MAIN
# ==============================

title "Preparing deployment manifest (v1)"

echo ""
prepare_manifest
echo ""
