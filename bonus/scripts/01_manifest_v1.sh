#!/usr/bin/env bash

set -euo pipefail

# ==============================
# CONFIGURATION
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly GITLAB_URL="http://gitlab.bonus.akurochk.com:8080"
readonly GITLAB_HOST="gitlab.bonus.akurochk.com:8080"
readonly USERNAME="root"

readonly PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab \
    -o jsonpath="{.data.password}" | base64 --decode)

readonly PROJECT_NAME="akurochk-IoT"
readonly GITLAB_REPO="${GITLAB_HOST}/${USERNAME}/${PROJECT_NAME}.git"

readonly TOKEN=$(curl -s \
    --request POST \
    --data "grant_type=password" \
    --data "username=root" \
    --data "password=${PASSWORD}" \
    "${GITLAB_URL}/oauth/token" | jq -r '.access_token')

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
    if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
        log_error_exit "token" "failed to obtain gitlab access token"
    fi
    log_warning "token" "exist"
}

clone_repository() {
    log_warning "repository" "cloning"

    rm -rf ${PROJECT_NAME}

    if git clone "http://${USERNAME}:${TOKEN}@${GITLAB_REPO}" >/dev/null; then
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
            >/dev/null

        log_success "repository" "created"
        git clone "http://${USERNAME}:${TOKEN}@${GITLAB_REPO}" >/dev/null
        log_success "repository" "cloned"
    fi
}

copy_manifest_v1() {
    log_warning "manifest" "copying v1"
    cp "${DIR_SCRIPT}/../confs/01_deployment_v1.yaml" "${DIR_SCRIPT}/${PROJECT_NAME}/deployment.yaml"
    log_success "manifest" "v1 copied"
}

commit_and_push() {
    log_warning "manifest" "updating to v1"

    cd "${PROJECT_NAME}"
    git add deployment.yaml
    if ! git diff --cached --quiet; then
        log_warning "manifest" "committing changes"
        git commit -m "chore: update deployment manifest (v1)" >/dev/null
        log_warning "manifest" "pushing changes"
        git push -u origin main >/dev/null
    fi
    log_success "manifest" "v1 ready"
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
copy_manifest_v1
commit_and_push
delete_local_repository
