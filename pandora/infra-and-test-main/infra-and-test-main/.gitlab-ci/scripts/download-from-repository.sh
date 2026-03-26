#!/bin/bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It downloads a file from a GitLab repository using the GitLab API.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - git must be installed
#   - curl must be installed
#   - jq must be installed
#   - the logger module must be available in the same directory as this script
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Source the logger module - assuming it's in the same directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Default configuration values
GL_API_URL="https://gitlab.com/api/v4"
COLLAPSED="true"

# Help function
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
Download a file from GitLab repository using the GitLab API.

Options:
  -p, --project-id ID       GitLab project ID (required)
  -t, --token TOKEN         GitLab private access token (required)
  -r, --ref REFERENCE       Name of branch, tag or commit. (required)
  -s, --source FILE         Path to the file in the repository (required)
  -o, --output FILE         Path to the output file (default: source file name)
  -v, --verbose             Enable verbose output
  -q, --quiet               Suppress all output except for errors
  --section-expanded        Start with expanded section(s)
  -h, --help                Show this help message and exit

Examples:
    $(basename "$0") --project-id 123456 --token my_token --ref main --source path/to/file.txt --output file.txt
    $(basename "$0") -p 123456 -t my_token -r main -s path/to/file.txt -o file.txt
EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -p|--project-id)
        PROJ_ID="$2"
        shift 2
        ;;
      -t|--token)
        TOKEN="$2"
        shift 2
        ;;
      -r|--ref)
        REF="$2"
        shift 2
        ;;
      -s|--source)
        SOURCE_PATH="$2"
        shift 2
        ;;
      -o|--output)
        OUTPUT_PATH="$2"
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
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  # Set default output path if not specified
  if [[ -z ${OUTPUT_PATH:-} && -n ${SOURCE_PATH:-} ]]; then
    OUTPUT_PATH=$(basename "${SOURCE_PATH}")
  fi

  # Check required arguments
  if [[ -z ${PROJ_ID:-} || -z ${TOKEN:-} || -z ${REF:-} || -z ${SOURCE_PATH:-} ]]; then
    log_error "Missing required arguments!"
    show_help
    exit 1
  fi
}

# Function to download the file
download_file() {
  local url="$1"
  local output="$2"
  local token="$3"

  # Create directory for output file if it doesn't exist
  local output_dir
  output_dir=$(dirname "$output")
  mkdir -p "$output_dir"

  # Create a temp file for downloading
  local temp_file
  temp_file=$(mktemp)

  log_debug "URL: $url"
  log_debug "Output: $output"

  # Download with curl showing progress
  if curl -L --fail \
       --header "PRIVATE-TOKEN: $token" \
       --progress-bar \
       --output "$temp_file" \
       "$url"; then

    # Move the temp file to the final destination
    mv "$temp_file" "$output"
    log_info "Successfully downloaded file: $output"
    return 0
  else
    local status=$?
    rm -f "$temp_file"
    log_error "Download failed with status: $status"
    return $status
  fi
}

# Main function that does the actual work
main() {
  log_info "Starting file download from GitLab repository"

  # Properly encode the file path for URL usage
  local url_encoded_file_path
  url_encoded_file_path=$(printf '%s' "$SOURCE_PATH" | jq -sRr @uri)

  # Construct the complete download URL
  local download_url="${GL_API_URL}/projects/${PROJ_ID}/repository/files/${url_encoded_file_path}/raw?ref=${REF}"

  # Download the file
  if download_file "$download_url" "$OUTPUT_PATH" "$TOKEN"; then
    # Get the absolute path of the downloaded file
    local absolute_path
    absolute_path=$(readlink -f "$OUTPUT_PATH")

    # Echo the absolute path for capture by the caller of this script
    log_info "File downloaded to: $absolute_path"
    echo "$absolute_path"
    return 0
  else
    exit 1
  fi
}

# Parse the arguments
parse_args "$@"

# Start the section (if in GitLab CI)
section_start "download_file" "Download $SOURCE_PATH from repository in project '$PROJ_ID'" "$COLLAPSED"

# Execute the main function
main

# End the section (if in GitLab CI)
section_end "download_file"
