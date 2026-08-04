#!/bin/bash
set -e

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

log_warning "bonus-cluster" "deleting"

if ! which k3d >/dev/null 2>&1; then
    log_error_exit "bonus-cluster" "failed to delete, k3d not installed"
fi

k3d cluster list | grep -qw "bonus-cluster" && k3d cluster delete bonus-cluster >/dev/null 2>&1

log_success "bonus-cluster" "deleted"
title "Done"
printf "\n"
