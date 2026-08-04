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

log_warning "p3-cluster" "deleting"

if ! which k3d >/dev/null 2>&1; then
    log_error_exit "p3-cluster" "failed to delete, k3d not installed"
fi

k3d cluster list | grep -qw "p3-cluster" && k3d cluster delete p3-cluster >/dev/null 2>&1

log_success "p3-cluster" "deleted"
title "Done"
printf "\n"
