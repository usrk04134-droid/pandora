#!/usr/bin/env bash
# ==============================================================================
# This script updates image tags in GitLab CI files (.gitlab-ci.yml and .gitlab-ci/*.yml)
# for a specific image name.
#
# It finds lines containing the image reference and replaces the old tag with the new one.
# ==============================================================================

set -euo pipefail

# Default values
IMAGE_NAME=""
NEW_TAG=""

# Help function
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
Update image tags in GitLab CI files for a specific image.

Options:
  --image-name NAME    The name of the image to update (required)
  --new-tag TAG        The new tag to use (required)
  -v, --verbose        Enable verbose output
  -h, --help           Show this help message and exit

Examples:
  $(basename "$0") --image-name adaptio-ci --new-tag adaptio-ci:1.2.3
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --image-name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --new-tag)
      NEW_TAG="$2"
      shift 2
      ;;
    -v|--verbose)
      set -x
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$IMAGE_NAME" || -z "$NEW_TAG" ]]; then
  echo "Error: --image-name and --new-tag are required"
  show_help
  exit 1
fi

# Extract the new version from NEW_TAG (assuming format name:version)
if [[ "$NEW_TAG" =~ ^${IMAGE_NAME}:(.+)$ ]]; then
  NEW_VERSION="${BASH_REMATCH[1]}"
else
  echo "Error: NEW_TAG does not match expected format ${IMAGE_NAME}:version"
  exit 1
fi

# Files to update
CI_FILES=(
  ".gitlab-ci.yml"
  ".gitlab-ci/*.yml"
)

echo "Updating image $IMAGE_NAME to version $NEW_VERSION"

# Function to update a file
update_file() {
  local file="$1"
  local temp_file
  temp_file=$(mktemp)

  # Use sed to replace the tag
  # Pattern: image: registry.gitlab.com/esab/abw/infra-and-test/IMAGE_NAME:old_version
  # Replace with: image: registry.gitlab.com/esab/abw/infra-and-test/IMAGE_NAME:NEW_VERSION
  sed -E "s|(image:.*registry\.gitlab\.com/esab/abw/infra-and-test/)${IMAGE_NAME}:[^\"']+|\1${IMAGE_NAME}:${NEW_VERSION}|g" "$file" > "$temp_file"

  # Check if file changed
  if ! cmp -s "$file" "$temp_file"; then
    mv "$temp_file" "$file"
    echo "Updated $file"
  else
    rm "$temp_file"
    echo "No changes needed in $file"
  fi
}

# Update each file
for pattern in "${CI_FILES[@]}"; do
  for file in $pattern; do
    if [[ -f "$file" ]]; then
      update_file "$file"
    fi
  done
done

echo "Image tag update completed"
