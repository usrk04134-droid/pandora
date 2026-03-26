# shellcheck disable=SC2148

# This file is intended to be sourced, not executed.
# It provides logging functions with different levels of verbosity and color coding.

# Define colors
[[ -z "${BOLD+x}" ]] && readonly BOLD="\x1b[1m"
[[ -z "${BLUE+x}" ]] && readonly BLUE="\x1b[94m"
[[ -z "${RED+x}" ]] && readonly RED="\x1b[91m"
[[ -z "${GREEN+x}" ]] && readonly GREEN="\x1b[92m"
[[ -z "${YELLOW+x}" ]] && readonly YELLOW="\x1b[93m"
[[ -z "${RESET+x}" ]] && readonly RESET="\x1b[0m"

# Default values
[[ -z "${VERBOSE+x}" ]] && VERBOSE=0
[[ -z "${QUIET+x}" ]] && QUIET=0

# Function for logging. Using stderr to not interfere with output on stdout.
function log() {
  local timestamp
  local level="${1}"
  local message="${2}"
  local color="${3}"

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  echo -e "${BLUE}[${timestamp}]${RESET} ${color}${BOLD}${level}${RESET} ${message}" >&2
}

function log_info() {
  if [[ $QUIET -eq 0 ]]; then
    log "INFO" "${1}" "${GREEN}"
  fi
}

function log_warn() {
  if [[ $QUIET -eq 0 ]]; then
    log "WARN" "${1}" "${YELLOW}"
  fi
}

function log_error() {
  if [[ $QUIET -eq 0 ]]; then
    log "ERROR" "${1}" "${RED}"
  fi
}

function log_debug() {
  if [[ $VERBOSE -eq 1 && $QUIET -eq 0 ]]; then
    log "DEBUG" "${1}" "${BLUE}"
  fi
}

# function for starting a Gitlab collapsible section
# $1 - Section title. String REQUIRED
# $2 - Section description. String
# $3 - Optional flag to start collapsed.
function section_start () {
  local section_title="${1}"
  local section_description="${2:-$section_title}"
  local section_collapsed="${3:+true}"
  : "${section_collapsed:=false}"

  echo -e "section_start:$(date +%s):${section_title}[collapsed=${section_collapsed}]\r\033[0K${section_description}" >&2
}

# Function for ending a Gitlab collapsible section
# $1 - Section title, SHALL match what was used with section_start(). String REQUIRED
function section_end () {
  local section_title="${1}"

  echo -e "section_end:$(date +%s):${section_title}\r\033[0K" >&2
}
