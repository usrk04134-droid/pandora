#!/usr/bin/env bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It retrieves the GitLab project ID for a given project name.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - curl must be installed
#   - jq must be installed
#   - the logger module must be available in the same directory as this script
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Before sourcing logger.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Default configuration values
GL_API_URL="https://gitlab.com/api/v4"
COLLAPSED="true"

# Help function
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
This script returns the GitLab project ID for the specified project name.

Options:
  -p, --project-name NAME   Name of the project to look up (required)
  -t, --token TOKEN         GitLab private access token (required)
  -v, --verbose             Enable verbose output
  -q, --quiet               Suppress all output except for the project ID
  --section-expanded        Start with expanded section(s)
  -h, --help                Show this help message and exit

Example:
  $(basename "$0") --project-name my_project --token my_token --verbose
  $(basename "$0") -p my_project -t my_token
EOF
}

# Function to parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -p|--project-name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      -t|--token)
        TOKEN="$2"
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
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done

  # Check required arguments
  if [[ -z ${PROJECT_NAME:-} || -z ${TOKEN:-} ]]; then
    log_error "Missing required arguments!"
    show_help
    exit 1
  fi
}

# Main function to get project ID
get_project_id() {
  local target_project_name="$1"
  local proj_id

  log_info "Looking up project ID for '$target_project_name'"
  projects_url="${GL_API_URL}/projects"
  project_path=$(echo "esab/abw/$target_project_name" | sed 's/\//%2F/g')

  proj_id=$(curl -sS --header "PRIVATE-TOKEN: $TOKEN" "$projects_url/$project_path" | jq '.id')

  if [[ -z "$proj_id" || "$proj_id" == "null" ]]; then
    log_error "Could not find project ID for '$target_project_name'"
    exit 1
  fi

  log_info "Found project id '${proj_id}' for $target_project_name"
  echo "$proj_id"
}


# Execute the parse_arguments function with all script arguments
parse_args "$@"

section_start "get_project_id" "Find project ID for '$PROJECT_NAME'" "$COLLAPSED"

# Execute the function and output the result
get_project_id "$PROJECT_NAME"

section_end "get_project_id"
