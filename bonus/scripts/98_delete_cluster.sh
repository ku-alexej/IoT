#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================

readonly GITLAB_DOMAIN="gitlab.bonus.akurochk.com"
readonly CLUSTER_NAME="bonus-cluster"

# ==============================
# LIBRARY
# ==============================

readonly DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR_SCRIPT}/lib/common.sh"

# ==============================
# MAIN
# ==============================

title "Deleting k3d cluster"
printf "\n"

log_warning "${CLUSTER_NAME}" "deleting"

if ! which k3d >/dev/null 2>&1; then
    log_error_exit "${CLUSTER_NAME}" "failed to delete, k3d not installed"
fi

k3d cluster list | grep -qw "${CLUSTER_NAME}" && k3d cluster delete "${CLUSTER_NAME}" >/dev/null 2>&1

log_success "${CLUSTER_NAME}" "deleted"

if grep -qxF "127.0.0.1 ${GITLAB_DOMAIN}" /etc/hosts 2>/dev/null; then
    log_warning "hosts" "removing ${GITLAB_DOMAIN} mapping"
    sudo sed -i.bak "/^127\.0\.0\.1 ${GITLAB_DOMAIN}\$/d" /etc/hosts
    log_success "hosts" "mapping removed"
fi

title "Done"
printf "\n"
