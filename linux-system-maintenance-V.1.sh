#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Project:     Linux System Maintenance
# Description: Automated updates, cleanup, disk optimization, and health checks
# Version:     "1.0.0"
# -----------------------------------------------------------------------------
# License: MIT
# Author: Jeong
# -----------------------------------------------------------------------------

set -u
IFS=$'\n\t'

#######################################
# Environment safety (CI / cron safe)
#######################################
TERM=${TERM:-dumb}
USE_TPUT=0
command -v tput >/dev/null && [[ "$TERM" != "dumb" ]] && [[ -t 1 ]] && USE_TPUT=1

#######################################
# UI Configuration
#######################################
ACCENT="\e[36m"
OK="\e[32m"
ERR="\e[31m"
DIM="\e[90m"
RESET="\e[0m"
BOLD="\e[1m"

#######################################
# Globals
#######################################
UPDATES_AVAILABLE=0
UPDATES_APPLIED=0
REMOVED_ESTIMATE=0
DISK_BEFORE_KB=0
DISK_AFTER_KB=0
FAILED_SERVICES=0
FAILED_SERVICE_NAMES=()

#######################################
# Signal Handling
#######################################
cleanup() {
    echo -e "\n${ERR}× Interrupted.${RESET}"
    [[ $USE_TPUT -eq 1 ]] && tput cnorm || true
    exit 130
}
trap cleanup INT TERM

#######################################
# Spinner (TTY safe)
#######################################
spinner() {
    local pid=$1
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    if [[ $USE_TPUT -eq 0 ]]; then
        wait "$pid"
        return
    fi

    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ▸ %s" "${spin:i++%${#spin}:1}"
        sleep 0.1
    done
    printf "\r"
    tput cnorm
    wait "$pid"
}

#######################################
# UI Helpers
#######################################
header() {
    [[ -t 1 ]] && clear
    echo -e "${BOLD}${ACCENT}System Maintenance${RESET}"
    echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S') • ${HOSTNAME:-unknown}${RESET}\n"
}

section() {
    echo -e "\n${BOLD}$1${RESET}"
}

run() {
    local label="$1"; shift
    echo -e "• $label"
    local start=$SECONDS

    "$@" >/dev/null 2>&1 &
    local pid=$!
    spinner "$pid"

    printf "  ▸ ${OK}done${RESET} (%ds)\n" "$((SECONDS-start))"
}

#######################################
# Keep sudo alive
#######################################
sudo -v || exit 1
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT

#######################################
# Detect OS / Package Manager
#######################################
. /etc/os-release || { echo "Cannot detect OS"; exit 1; }

case "${ID_LIKE:-$ID}" in
    *debian*) PM="apt" ;;
    *rhel*|*fedora*) PM="dnf" ;;
    *arch*) PM="pacman" ;;
    *) echo "Unsupported distro: $ID"; exit 1 ;;
esac

#######################################
# Execution
#######################################
header

section "System Status"
printf "  Load     %s\n" "$(awk '{print $1,$2,$3}' /proc/loadavg)"
printf "  Memory   %s\n" "$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
printf "  Disk     %s\n" "$(df -h / | awk 'NR==2 {print $5}')"

DISK_BEFORE_KB=$(df --output=avail / | tail -1)

#######################################
# Updates
#######################################
section "Updates"

case "$PM" in
apt)
    run "Updating package index" sudo apt-get update -y
    UPDATES_AVAILABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
    run "Applying upgrades" sudo apt-get full-upgrade -y
    UPDATES_APPLIED=$UPDATES_AVAILABLE
    ;;
dnf)
    UPDATES_AVAILABLE=$(dnf check-update -q || true | grep -vc '^$')
    run "Applying upgrades" sudo dnf upgrade -y
    UPDATES_APPLIED=$UPDATES_AVAILABLE
    ;;
pacman)
    UPDATES_AVAILABLE=$(pacman -Qu 2>/dev/null | wc -l)
    run "Applying upgrades" sudo pacman -Syu --noconfirm
    UPDATES_APPLIED=$UPDATES_AVAILABLE
    ;;
esac

#######################################
# Cleanup
#######################################
section "Smart Cleanup"

case "$PM" in
apt)
    REMOVED_ESTIMATE=$(dpkg -l | awk '/^rc/ {c++} END{print c+0}')
    run "Removing unused packages" sudo apt-get autoremove --purge -y
    run "Cleaning package cache" sudo apt-get autoclean -y
    ;;
dnf)
    run "Removing unused packages" sudo dnf autoremove -y
    ;;
pacman)
    mapfile -t ORPHANS < <(pacman -Qtdq 2>/dev/null || true)
    REMOVED_ESTIMATE=${#ORPHANS[@]}
    (( REMOVED_ESTIMATE > 0 )) && \
        run "Removing orphaned packages" sudo pacman -Rns --noconfirm "${ORPHANS[@]}"
    ;;
esac

#######################################
# Logs & Disk
#######################################
run "Vacuuming journal logs" sudo journalctl --vacuum-time=7d

if command -v fstrim >/dev/null; then
    run "TRIM unused blocks" sudo fstrim / || \
        echo -e "  ${DIM}▸ fstrim not supported${RESET}"
fi

DISK_AFTER_KB=$(df --output=avail / | tail -1)
DISK_RECOVERED_MB=$(( (DISK_AFTER_KB - DISK_BEFORE_KB) / 1024 ))
(( DISK_RECOVERED_MB < 0 )) && DISK_RECOVERED_MB=0

#######################################
# Service Health
#######################################
section "Service Health"

mapfile -t FAILED_SERVICE_NAMES < <(
    systemctl list-units \
        --state=failed \
        --type=service \
        --no-legend \
        --output=json 2>/dev/null \
    | jq -r '.[].unit'
)

FAILED_SERVICES=${#FAILED_SERVICE_NAMES[@]}

if (( FAILED_SERVICES == 0 )); then
    echo -e "• ${OK}All services healthy${RESET}"
else
    echo -e "• ${ERR}$FAILED_SERVICES failed services:${RESET}"
    for svc in "${FAILED_SERVICE_NAMES[@]}"; do
        echo -e "  ${DIM}└─${RESET} ${ERR}${svc}${RESET}"
    done
fi

#######################################
# Summary
#######################################
section "Summary"
printf "  Updates available  %d\n" "$UPDATES_AVAILABLE"
printf "  Updates applied    %d\n" "$UPDATES_APPLIED"
printf "  Packages removed   %d (estimate)\n" "$REMOVED_ESTIMATE"
printf "  Disk recovered     %d MB\n" "$DISK_RECOVERED_MB"
printf "  Services failed    %d\n" "$FAILED_SERVICES"

echo -e "\n${DIM}Maintenance complete${RESET}"
