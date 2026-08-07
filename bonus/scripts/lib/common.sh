set -e

# ==============================
# COLORS
# ==============================

readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly WHITE="\033[1;37m"
readonly RESET="\033[0m"

# ==============================
# LOG FUNCTIONS
# ==============================

title() {
    local text=$1
    printf "\n${WHITE}>>> %s <<<${RESET}\n" "$text"
}

log_step() {
    local number=$1
    local total=$2
    local text=$3
    printf "\n[%s/%s] %s:\n" "$number" "$total" "$text"
}

status() {
    local name="$1"
    local status="$2"
    local color="$3"
    printf "     - %-10s : ${color}%s${RESET}\n" "$name" "$status"
    sleep 1
}

log_success() {
    status "$1" "$2" "$GREEN"
}

log_warning() {
    status "$1" "$2" "$YELLOW"
}

log_error_exit() {
    status "$1" "$2" "$RED"
    echo ""
    exit 1
}
