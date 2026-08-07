#!/usr/bin/env bash

set -euo pipefail

# ==============================
# CONFIGURATION
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly GITLAB_URL="http://gitlab.akurochk.com"
readonly GITLAB_HOST="gitlab.akurochk.com"
readonly GIT_USER="akurochk"
readonly GIT_EMAIL="akurochk@student.42.fr"
readonly USERNAME="root"

readonly PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab \
    -o jsonpath="{.data.password}" | base64 --decode)

readonly PROJECT_NAME="akurochk-IoT"
readonly GITLAB_REPO="${GITLAB_HOST}/${USERNAME}/${PROJECT_NAME}.git"

TOKEN=""

# ==============================
# LIBRARY
# ==============================

source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# TOOLS
# ==============================

check_token() {

    log_warning "token" "checking"
    sleep 15

    TOKEN=$(curl -s \
    --request POST \
    --data "grant_type=password" \
    --data "username=root" \
    --data "password=${PASSWORD}" \
    "${GITLAB_URL}/oauth/token" | jq -r '.access_token')

    printf "token: %s\n" "${TOKEN}"

    if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
        log_error_exit "token" "failed to obtain gitlab access token"
    fi

    log_success "token" "exist"
}

clone_repository() {
    log_warning "repository" "cloning"

    rm -rf ${PROJECT_NAME}

    if git clone "http://${USERNAME}:${TOKEN}@${GITLAB_REPO}" >/dev/null 2>&1; then
        log_success "repository" "cloned"
    else
        log_warning "repository" "does not exist"
        log_warning "repository" "creating"
        curl --fail \
            --request POST \
            --header "Authorization: Bearer ${TOKEN}" \
            --data "name=${PROJECT_NAME}" \
            --data "path=${PROJECT_NAME}" \
            --data "visibility=public" \
            "${GITLAB_URL}/api/v4/projects" \
            >/dev/null 2>&1

        log_success "repository" "created"
        git clone "http://${USERNAME}:${TOKEN}@${GITLAB_REPO}" >/dev/null 2>&1
        log_success "repository" "cloned"
    fi
}

copy_manifest_v2() {
    log_warning "manifest" "copying v2"
    cp "${DIR_SCRIPT}/../confs/01_deployment_v2.yaml" "${DIR_SCRIPT}/${PROJECT_NAME}/deployment.yaml"
    log_success "manifest" "v2 copied"
}

commit_and_push() {
    log_warning "manifest" "updating to v2"

    cd "${PROJECT_NAME}"
    git config --local user.name "$GIT_USER"
    git config --local user.email "$GIT_EMAIL"

    git add deployment.yaml
    if ! git diff --cached --quiet; then
        log_warning "manifest" "committing changes"
        git commit -m "chore: update deployment manifest (v2)" >/dev/null
        log_warning "manifest" "pushing changes"
        git push -u origin main >/dev/null 2>&1
    fi
    log_success "manifest" "v2 ready"
}

delete_local_repository() {
    cd "${DIR_SCRIPT}"
    rm -rf "${PROJECT_NAME}"
}

# ==============================
# MAIN
# ==============================

check_token
clone_repository
copy_manifest_v2
commit_and_push
delete_local_repository
