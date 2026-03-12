#!/usr/bin/env bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It updates the software versions in a manifest file based on the versions
# found for the equivalent software names in the flake.lock file.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - git must be installed
#   - jq must be installed
#   - yq must be installed
#   - the logger module must be available in the same directory as this script
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Default values
FLAKE_LOCK_PATH="flake.lock"
COLLAPSED="true"

# Source the logger module
# Assuming the logger is in the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Display help
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Update software versions in a manifest file based on flake.lock references.

Options:
  -c, --component NAME      Component name in the manifest to update (required)
  -n, --flake-name NAME     Name of the flake software entry (required)
  -r, --flake-rev REV       Revision of the flake (required)
  -f, --flake-ref REF       Reference of the flake (required)
  -m, --manifest PATH       Path to the manifest file (required)
  -l, --lock PATH           Path to the flake.lock file (default: flake.lock)
  -v, --verbose             Enable verbose output
  -q, --quiet               Suppress all output except for errors
  --section-expanded        Start with expanded section(s)
  -h, --help                Show this help message and exit

Example:
  $(basename "$0") --component my-component --flake-name my-flake --flake-rev abc123 --flake-ref 1.0.0 --manifest manifest.yaml
  $(basename "$0") --component my-component --flake-name my-flake --flake-rev abc123 --flake-ref 1.0.0 --manifest manifest.yaml --lock flake.lock --verbose
EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--component)
        COMPONENT_NAME="$2"
        shift 2
        ;;
      -n|--flake-name)
        FLAKE_NAME="$2"
        shift 2
        ;;
      -r|--flake-rev)
        FLAKE_REV="$2"
        shift 2
        ;;
      -f|--flake-ref)
        FLAKE_REF="$2"
        shift 2
        ;;
      -m|--manifest)
        MANIFEST_PATH="$2"
        shift 2
        ;;
      -l|--lock)
        FLAKE_LOCK_PATH="$2"
        shift 2
        ;;
      -q|--quiet)
        QUIET=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
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

  # Check required arguments
  if [[ -z ${COMPONENT_NAME:-} || -z ${FLAKE_NAME:-} || -z ${FLAKE_REV:-} || -z ${FLAKE_REF:-} || -z ${MANIFEST_PATH:-} ]]; then
    log_error "Missing required arguments!"
    show_help
    exit 1
  fi
}

# Function to validate if a string is a semantic version (semver)
is_semver() {
  local version="$1"
  # Pattern explanation:
  # ^[0-9]+\.[0-9]+\.[0-9]+                 - Required core version (major.minor.patch)
  # (-[0-9A-Za-z.-]+)?$                     - Optional pre-release segment
  #
  # Examples of valid versions:
  # - 1.2.3         (standard)
  # - 0.1.0-1       (with numeric pre-release)
  # - 1.0.0-alpha.1 (with alphanumeric pre-release)
  # - 2.3.4-rc.2    (with named pre-release)
  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)((-[0-9A-Za-z.-]+)?)$ ]]; then
    return 0
  else
    log_debug "Version '$version' is not a semantic version"
    return 1
  fi
}

# Function to get a version from the flake.lock for a given node name
get_version_from_flake_lock() {
  local node_name="$1"
  # Skip if flake.lock doesn't exist
  if [[ ! -f "$FLAKE_LOCK_PATH" ]]; then
    log_warn "Flake lock file not found: $FLAKE_LOCK_PATH"
    return 1
  fi
  # Get software part version from the flake.lock file
  local ref_version
  ref_version=$(jq -r --arg name "$node_name" '.nodes[$name].original.ref // ""' "$FLAKE_LOCK_PATH")
  # Return version if it's a valid semver, otherwise return empty
  if [[ -n "$ref_version" && "$ref_version" != "null" ]] && is_semver "$ref_version"; then
    log_debug "Found semantic version for '$node_name': $ref_version"
    echo "$ref_version"
    return 0
  fi
  # If no valid semver found, use the rev version
  local rev_version
  rev_version=$(jq -r --arg name "$node_name" '.nodes[$name].original.rev // ""' "$FLAKE_LOCK_PATH")
  if [[ -n "$rev_version" && "$rev_version" != "null" ]]; then
    log_debug "No valid semver found for '$node_name' in flake.lock, using rev: $rev_version"
    echo "$rev_version"
    return 0
  fi
  log_debug "No version found for '$node_name' in flake.lock"
  return 1
}

# Function to update a software version
update_version() {
  local component="$1"
  local software="$2"
  local new_version="$3"
  current_version=$(yq "
    .components[]
    | select(.name == \"$component\")
    | .software[]
    | select(.name == \"$software\")
    | .version
  " "$MANIFEST_PATH")
  if [ "$current_version" == "$new_version" ]; then
    log_debug "Version already set to '$new_version'. Skipping!"
    return 1
  fi
  yq -i "
    (.components[]
      | select(.name == \"$component\")
      .software[]
      | select(.name == \"$software\")
    ).version = \"$new_version\"
  " "$MANIFEST_PATH"
  log_info "Updated '$software' in '$component' to version '$new_version'"
  return 0
}

# Function to increment the manifest version
increment_manifest_version() {
  local current_version prefix number new_number new_version
  # Get current version
  current_version=$(yq eval '.version' "$MANIFEST_PATH")
  log_debug "Current version: $current_version"
  # Parse version (expecting format like "1.0.0-rc.5")
  if [[ "$current_version" =~ ^(.*-rc\.)([0-9]+)$ ]]; then
    prefix="${BASH_REMATCH[1]}"  # Everything up to and including "-rc."
    number="${BASH_REMATCH[2]}"  # Just the number after "-rc."
    # Validate the extracted number is numeric
    if ! [[ "$number" =~ ^[0-9]+$ ]]; then
      log_error "Extracted version number '$number' is not numeric"
      return 1
    fi
    # Increment the version number
    new_number=$((number + 1))
    new_version="${prefix}${new_number}"
    yq eval ".version = \"$new_version\"" -i "$MANIFEST_PATH"
    log_info "Updated manifest version to '$new_version'"
  else
    log_error "Could not parse version format: '$current_version'"
    log_error "Expected format: 'something-rc.N'"
    return 1
  fi
}

# Main function
update_manifest() {
  log_info "Update software versions for manifest component: $COMPONENT_NAME"
  # Flag to track if any versions were updated
  local versions_updated=false
  # Check flake.lock file exists
  if [[ -f "$FLAKE_LOCK_PATH" ]]; then
    log_info "Found flake.lock file, will extract versions for matching software"
  else
    log_error "Flake lock file not found: $FLAKE_LOCK_PATH"
    exit 1
  fi
  # Check if component exists and extract its software
  log_debug "Extracting software list from component '$COMPONENT_NAME'"
  software_list=$(yq ".components[] | select(.name == \"$COMPONENT_NAME\") | .software" "$MANIFEST_PATH")
  if [[ -z "$software_list" || "$software_list" == "null" ]]; then
    log_error "Component '$COMPONENT_NAME' not found or has no software"
    exit 1
  fi
  software_count=$(echo "$software_list" | yq 'length')
  log_info "Found $software_count software entries"
  # Iterate over software and get version from flake.lock
  log_debug "Iterating through software entries"
  for i in $(seq 0 $((software_count - 1))); do
    software_name=$(echo "$software_list" | yq ".[$i].name")
    if [[ -z "$software_name" || "$software_name" == "null" ]]; then
      log_warn "Skipping software entry $i with no name"
      continue
    fi
    # Get current version if exists (for debug output)
    current_version=$(echo "$software_list" | yq ".[$i].version")
    if [[ "$current_version" == "null" ]]; then
      current_version=""
    fi
    # Get version directly from flake.lock, or empty string if not found
    version_to_use=$(get_version_from_flake_lock "$software_name") || version_to_use=""
    # Log appropriate message based on what we found
    if [[ -n "$version_to_use" ]]; then
      log_info "Using version for '$software_name': $version_to_use"
    else
      log_debug "No flake.lock version found for '$software_name', using empty version"
    fi
    log_debug "Adding software: $software_name (manifest: ${current_version:-empty}, flake: ${version_to_use:-empty})"
    # If update_version returns 0 (success), it means a version was updated
    if update_version "$COMPONENT_NAME" "$software_name" "$version_to_use"; then
      versions_updated=true
    fi
  done
  # Add the flake version
  if is_semver "$FLAKE_REF"; then
    version_to_use="$FLAKE_REF"
  else
    version_to_use="$FLAKE_REV"
  fi
  # If update_version returns 0 (success), it means a version was updated
  if update_version "$COMPONENT_NAME" "$FLAKE_NAME" "$version_to_use"; then
    versions_updated=true
  fi
  # Check if any versions were updated
  if $versions_updated; then
    log_debug "Version changes detected, incrementing manifest version"
    increment_manifest_version
  else
    log_info "No version changes were needed"
  fi
}

# Parse command line arguments
parse_args "$@"

section_start "update_manifest" "Update Manifest" "$COLLAPSED"

# Run the main function
update_manifest

section_end "update_manifest"
