#!/usr/bin/env bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It finds the branch name containing a specific commit SHA.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - git must be installed
#   - the logger module must be available in the same directory as this script
#   - the script must be run in a git repository
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Source the logger module
# Assuming the logger is in the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Default values
BRANCH_PATTERNS=("origin/main" "origin/release/*")
COLLAPSED="true"

# Show help message
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] COMMIT_SHA

Find the branch name containing a specific commit SHA.

Options:
  -b, --branches PATTERN   Search only in branches matching the given pattern (default: "origin/main origin/release/*")
  -q, --quiet              Suppress all output except for the branch name
  -v, --verbose            Enable verbose output
  --section-expanded       Start with expanded section(s)
  -h, --help               Show this help message and exit

Example:
  $(basename "$0") abc1234
  $(basename "$0") -b "origin/feature/*" abc1234
EOF
}

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--branches)
        # Split the argument by spaces and convert to array
        IFS=' ' read -r -a BRANCH_PATTERNS <<< "$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -q|--quiet)
        QUIET=1
        shift
        ;;
      --section-expanded)
        COLLAPSED=""
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        if [[ -z ${COMMIT_SHA:-} ]]; then
          COMMIT_SHA="$1"
          shift
        else
          log_error "Too many arguments: $1"
          show_help
          exit 1
        fi
        ;;
    esac
  done

  # Check if commit SHA is provided
  if [[ -z ${COMMIT_SHA:-} ]]; then
    log_error "Commit SHA is required"
    show_help
    exit 1
  fi
}

# Main function to find branch containing commit
find_branch() {
  log_debug "Fetching all remote branches"
  git fetch --all

  log_debug "Searching for commit $COMMIT_SHA in branches matching: ${BRANCH_PATTERNS[*]}"
  branches=$(git branch -r --contains "$COMMIT_SHA" -- "${BRANCH_PATTERNS[@]}")

  if [[ -z "$branches" ]]; then
    log_error "No branch found containing commit $COMMIT_SHA"
    exit 1
  fi

  branch_count=$(echo "$branches" | wc -l)
  if [[ "$branch_count" -gt 1 ]]; then
    log_error "More than one branch found containing commit $COMMIT_SHA:"
    log_error "$branches"
    exit 1
  fi

  BRANCH_NAME=$(echo "$branches" | tr -d ' ' | sed 's|origin/||g')
  log_info "Found branch name: ${BRANCH_NAME}"

  # Print only the branch name (for use in scripts)
  echo "$BRANCH_NAME"
}

# Parse command line arguments
parse_args "$@"

section_start "get_branch_name" "Find branch name for commit '$COMMIT_SHA'" "$COLLAPSED"

# Execute the main function
find_branch

section_end "get_branch_name"
