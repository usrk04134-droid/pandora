#!/usr/bin/env bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It creates a GitLab merge request for changed files, approves it, and merges it.
#
# In the event of a failure at any step, it will attempt to clean up by closing
# the merge request and deleting the branch.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - git must be installed
#   - curl must be installed
#   - jq must be installed
#   - the logger module must be available in the same directory as this script
#   - the script must be run in a git repository
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Source the logger module - assuming it's in the same directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Default configuration values
GL_API_URL="https://gitlab.com/api/v4"
BRANCH_PREFIX="update-files"
MR_TITLE="chore: Update changed files"
MR_DESCRIPTION="This MR contains automated changes"
JIRA_ID="NONE"
ADD_ALL_TRACKED=false
COLLAPSED="true"
# Timeout settings
CURL_TIMEOUT=30              # Timeout for individual curl calls (seconds)
CURL_MAX_TIME=60            # Maximum time for curl operations (seconds)

# Global variables to track resources for cleanup
CREATED_BRANCH=""
CREATED_MR_ID=""

# Help function
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
Create, approve, and merge a GitLab merge request for changed files.

Options:
  -p, --project-id ID         GitLab project ID (required)
  -t, --token TOKEN           GitLab private access token (required)
  -b, --branch BRANCH         Target branch (required)
  -f, --path-filter PATH      Path filter for files to include (required if --all-tracked not used)
  --all-tracked               Add all tracked files with changes (required if --path-filter not used)
  --mr-branch-prefix PREFIX   Prefix for new branch name before timestamp (default: $BRANCH_PREFIX)
  --mr-title TITLE            Title for the merge request (default: "$MR_TITLE")
  --mr-description DESC       Description for the merge request (default: "$MR_DESCRIPTION")
  --jira-id ID                JIRA issue ID to reference in commit (default: "$JIRA_ID")
  --curl-timeout SECONDS      Timeout for curl connections (default: $CURL_TIMEOUT)
  --curl-max-time SECONDS     Maximum time for curl operations (default: $CURL_MAX_TIME)
  -v, --verbose               Enable verbose output
  -q, --quiet                 Suppress all output except for errors
  --section-expanded          Start with expanded section(s)
  -h, --help                  Show this help message and exit

Examples:
  # Create MR with changes from specific path
  $(basename "$0") --project-id 123 --token glpat-XXXXX --branch main --path-filter ./configs/

  # Create MR with all changed files
  $(basename "$0") --project-id 123 --token glpat-XXXXX --branch main --all-tracked

  # Create MR with custom branch and title
  $(basename "$0") --project-id 123 --token glpat-XXXXX --branch main --all-tracked --mr-branch-prefix feature-update --mr-title "feat: Update dependencies"

  # Create MR with custom timeouts
  $(basename "$0") --project-id 123 --token glpat-XXXXX --branch main --all-tracked --curl-timeout 45 --curl-max-time 90
EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -p|--project-id)
        PROJECT_ID="$2"
        shift 2
        ;;
      -t|--token)
        TOKEN="$2"
        shift 2
        ;;
      -b|--branch)
        TARGET_BRANCH="$2"
        shift 2
        ;;
      -f|--path-filter)
        PATH_FILTER="$2"
        shift 2
        ;;
      --mr-branch-prefix)
        BRANCH_PREFIX="$2"
        shift 2
        ;;
      --mr-title)
        MR_TITLE="$2"
        shift 2
        ;;
      --mr-description)
        MR_DESCRIPTION="$2"
        shift 2
        ;;
      --jira-id)
        JIRA_ID="$2"
        shift 2
        ;;
      --curl-timeout)
        CURL_TIMEOUT="$2"
        shift 2
        ;;
      --curl-max-time)
        CURL_MAX_TIME="$2"
        shift 2
        ;;
      --all-tracked)
        ADD_ALL_TRACKED=true
        shift
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
        show_help
        exit 1
        ;;
    esac
  done

  # Check required arguments
  if [[ -z ${GL_API_URL:-} || -z ${PROJECT_ID:-} || -z ${TOKEN:-} || -z ${TARGET_BRANCH:-} ]]; then
    log_error "Missing required arguments!"
    show_help
    exit 1
  fi

  # Check that either path filter is provided or all-tracked is specified
  if [[ -z "${PATH_FILTER:-}" && "$ADD_ALL_TRACKED" == "false" ]]; then
    log_error "Either --path-filter or --all-tracked must be specified!"
    show_help
    exit 1
  fi
}

# curl wrapper with timeout and error handling
safe_curl() {
  # Redact token from log output
  local debug_cmd
  debug_cmd="${*/PRIVATE-TOKEN: [^ ]*/PRIVATE-TOKEN: [REDACTED]}"
  log_debug "Curling '$debug_cmd' with timeout settings: --connect-timeout $CURL_TIMEOUT --max-time $CURL_MAX_TIME"

  # Execute curl with timeouts and error handling
  if timeout $((CURL_MAX_TIME + 10)) curl \
    --connect-timeout "$CURL_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    --retry 0 \
    --fail \
    --silent \
    --show-error \
    "$@" 2>/dev/null; then
    return 0
  else
    local exit_code=$?
    case $exit_code in
      7)
        log_warn "Connection failed (network unreachable)"
        ;;
      28)
        log_warn "Operation timeout (exceeded ${CURL_MAX_TIME}s)"
        ;;
      22)
        log_warn "HTTP error (4xx/5xx response)"
        ;;
      124)
        log_warn "Command timeout (exceeded $((CURL_MAX_TIME + 10))s total)"
        ;;
      *)
        log_warn "Curl failed with exit code: $exit_code"
        ;;
    esac
    return $exit_code
  fi
}

# Retry wrapper function for API calls with timeout handling
retry_api_call() {
  local max_retries=3
  local retry_delay=5
  local attempt=1

  while [[ $attempt -le $max_retries ]]; do
    log_debug "API call attempt $attempt/$max_retries"

    if safe_curl "$@"; then
      return 0
    else
      local exit_code=$?
      log_warn "API call failed (attempt $attempt/$max_retries) with exit code: $exit_code"

      # Don't retry on certain errors that won't be fixed by retrying
      case $exit_code in
        22)  # HTTP 4xx errors (client errors like 401 Unauthorized, 404 Not Found) - won't retry these
          if [[ $attempt -eq 1 ]]; then
            log_error "HTTP client error detected. This might be an authentication or request format issue."
          fi
          ;;
        7)  # Connection failed (network unreachable, DNS failure, or timeout)
          log_info "Connection failed - this might be temporary network issue"
          ;;
      esac

      if [[ $attempt -lt $max_retries ]]; then
        log_info "Retrying in ${retry_delay} seconds... (backoff strategy)"
        sleep $retry_delay
        retry_delay=$((retry_delay * 2))  # Exponential backoff
      fi
      ((attempt++))
    fi
  done

  log_error "API call failed after $max_retries attempts"
  return 1
}

# Cleanup function to close MR and delete branch on failure
cleanup_on_failure() {
  log_error "Cleaning up resources due to failure..."
  log_debug "CREATED_MR_ID='${CREATED_MR_ID:-}', CREATED_BRANCH='${CREATED_BRANCH:-}'"

  # Update and close merge request if it was created
  if [[ -n "$CREATED_MR_ID" ]]; then
    log_info "Updating and closing Merge Request #${CREATED_MR_ID}..."
    local temp_file
    temp_file=$(mktemp)

    # Update the MR with failure information
    local failure_description="This MR was automatically closed due to failure during the CI/CD process.

Original description:
${MR_DESCRIPTION}"
    local failure_title="[FAILED] ${MR_TITLE}"

    if retry_api_call -X PUT --header "PRIVATE-TOKEN: $TOKEN" \
      --data "title=${failure_title}&description=${failure_description}&state_event=close" \
      "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${CREATED_MR_ID}" > "$temp_file"; then
      log_info "Merge Request #${CREATED_MR_ID} updated and closed successfully"
    else
      log_warn "Failed to update and close Merge Request #${CREATED_MR_ID}, but continuing cleanup"
      log_debug "API response: $(cat "$temp_file" 2>/dev/null || echo 'no response file')"
    fi
    rm -f "$temp_file"
  else
    log_info "No Merge Request ID to update (CREATED_MR_ID is empty)"
  fi

  # Delete branch if it was created
  if [[ -n "$CREATED_BRANCH" ]]; then
    log_info "Deleting branch '${CREATED_BRANCH}' via GitLab API..."
    local temp_file
    temp_file=$(mktemp)

    # URL encode the branch name
    local encoded_branch
    encoded_branch=$(printf '%s' "$CREATED_BRANCH" | jq -sRr @uri)
    log_debug "Encoded branch name: '${encoded_branch}'"

    if retry_api_call -X DELETE --header "PRIVATE-TOKEN: $TOKEN" \
      "${GL_API_URL}/projects/${PROJECT_ID}/repository/branches/${encoded_branch}" > "$temp_file"; then
      log_info "Branch '${CREATED_BRANCH}' deleted successfully via API"
    else
      log_warn "Failed to delete branch '${CREATED_BRANCH}' via API, but continuing cleanup"
      log_debug "API response: $(cat "$temp_file" 2>/dev/null || echo 'no response file')"
    fi
    rm -f "$temp_file"
  else
    log_info "No branch name to delete (CREATED_BRANCH is empty)"
  fi

  log_info "Cleanup completed"
}

# Function that can be called to wait for the pipeline to start
wait_for_pipeline_start() {
  local pipeline_id
  local mr_id="$1"
  log_info "Waiting for pipeline to start for MR #${mr_id}..."
  local max_retries=30
  local retries=0

  while [[ $retries -lt $max_retries ]]; do
    local temp_file
    temp_file=$(mktemp)

    if retry_api_call --header "PRIVATE-TOKEN: $TOKEN" \
      "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}" > "$temp_file"; then

      pipeline_id=$(jq -r 'if .head_pipeline == null then "" else .head_pipeline.id end' "$temp_file")
      rm -f "$temp_file"

      if [ -z "$pipeline_id" ]; then
        log_warn "No pipeline found. Checking again in a few seconds... ($((retries + 1))/$max_retries)"
        sleep 5
        ((retries++))
        continue
      else
        break
      fi
    else
      log_warn "Failed to check pipeline status. Retrying... ($((retries + 1))/$max_retries)"
      rm -f "$temp_file"
      sleep 5
      ((retries++))
      continue
    fi
  done

  if [[ $retries -eq $max_retries ]]; then
    log_error "No pipeline started after $max_retries attempts. Aborting."
    cleanup_on_failure
    exit 1
  fi

  log_debug "Found pipeline: ${pipeline_id}"
  echo "$pipeline_id"
}

# Function that can be called to wait for a pipeline to finish
check_pipeline_status() {
  local pipeline_id="$1"
  log_info "Checking pipeline status for pipeline #${pipeline_id}..."
  local interval=15   # Check interval in seconds
  local elapsed=0

  while true; do
    # Use a temporary file to store the API response
    local temp_file
    temp_file=$(mktemp)

    log_debug "Get pipeline status..."
    if retry_api_call --header "PRIVATE-TOKEN: $TOKEN" \
      "${GL_API_URL}/projects/${PROJECT_ID}/pipelines/${pipeline_id}" > "$temp_file"; then

      local pipeline_status
      pipeline_status=$(jq -r '.status' "$temp_file")

      # Clean up temp file
      rm -f "$temp_file"

      # Handle status values
      case "$pipeline_status" in
        "success")
          log_info "Pipeline finished successfully!"
          return 0
          ;;
        "failed"|"canceled"|"skipped")
          log_error "Pipeline failed, canceled or skipped! Status: ${pipeline_status}"
          cleanup_on_failure
          exit 1
          ;;
        *)
          log_debug "Pipeline status: ${pipeline_status}. Waiting ${interval} seconds... (elapsed: ${elapsed}s)"
          ;;
      esac
    else
      log_warn "Failed to fetch pipeline status. Will retry in ${interval} seconds..."
      rm -f "$temp_file"
    fi

    # Wait before checking again
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
}

# Create a new branch with modified files
create_branch_with_changes() {
  local new_branch="$1"
  local target_branch="$2"

  # Check for modified files
  if [[ "$ADD_ALL_TRACKED" == "true" ]]; then
    log_info "Checking for all tracked files with changes"
    MODIFIED_FILES=$(git diff --name-only)
  else
    log_debug "Path filter: ${PATH_FILTER}"
    log_info "Checking for modified files in ${PATH_FILTER}"
    MODIFIED_FILES=$(git diff --name-only -- "$PATH_FILTER")
  fi

  if [[ -z "$MODIFIED_FILES" ]]; then
    log_error "No modified files to add!"
    cleanup_on_failure
    exit 1
  fi

  log_info "Found modified files:"
  echo "$MODIFIED_FILES"

  # Create a new branch for the changes
  log_info "Creating new branch: ${new_branch}"
  git checkout -b "$new_branch" "$target_branch"

  # Add the modified files
  if [[ "$ADD_ALL_TRACKED" == "true" ]]; then
    log_info "Adding all tracked files with changes"
    git add -u
  else
    log_info "Adding files matching path filter: ${PATH_FILTER}"
    git add "$PATH_FILTER"
  fi

  # Check if there are changes staged for commit
  if ! git diff --staged --quiet; then
    git commit -m "${MR_TITLE}" -m "${MR_DESCRIPTION}" -m "Issues: ""${JIRA_ID}"
  else
    log_error "No changes to commit!"
    git checkout "$target_branch"
    cleanup_on_failure
    exit 1
  fi

  # Push the new branch
  log_info "Pushing changes to branch: ${new_branch}"
  git push origin "$new_branch"
  git checkout "$target_branch"
}

# Create a merge request
create_merge_request() {
  local source_branch="$1"
  local target_branch="$2"

  log_info "Creating Merge Request"
  local temp_file
  temp_file=$(mktemp)

  if retry_api_call -X POST --header "PRIVATE-TOKEN: $TOKEN" \
    --data "source_branch=${source_branch}&target_branch=${target_branch}&title=${MR_TITLE}&description=${MR_DESCRIPTION}&remove_source_branch=true" \
    "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests" > "$temp_file"; then

    MR_ID=$(jq '.iid' "$temp_file")
    MR_URL=$(jq -r '.web_url' "$temp_file")
    rm -f "$temp_file"

    if [[ -z "$MR_ID" || "$MR_ID" == "null" ]]; then
      log_error "Failed to create Merge Request! Invalid response."
      cleanup_on_failure
      exit 1
    fi

    log_info "Merge Request created: ${MR_URL} (ID: ${MR_ID})"
    echo "$MR_ID"
  else
    rm -f "$temp_file"
    log_error "Failed to create Merge Request after retries!"
    cleanup_on_failure
    exit 1
  fi
}

# Approve the merge request
approve_merge_request() {
  local mr_id="$1"

  log_info "Approving Merge Request #${mr_id}"
  local temp_file
  temp_file=$(mktemp)

  if retry_api_call -X POST --header "PRIVATE-TOKEN: $TOKEN" \
    "${GL_API_URL}/projects/$PROJECT_ID/merge_requests/${mr_id}/approve" > "$temp_file"; then

    MR_MERGE_STATUS=$(jq -r '.merge_status' "$temp_file")
    MR_APPROVED=$(jq -r '.approved' "$temp_file")
    rm -f "$temp_file"

    # Sometimes the '.approved' field is not updated immediately in the approval response
    if [[ "$MR_MERGE_STATUS" != "can_be_merged" || "$MR_APPROVED" != "true" ]]; then
      log_warn "Waiting for approval state to update"
      sleep 5  # Wait state to be updated

      local approval_temp_file
      approval_temp_file=$(mktemp)

      if retry_api_call --header "PRIVATE-TOKEN: $TOKEN" \
        "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}/approval_state" > "$approval_temp_file"; then

        APPROVAL_STATE=$(jq -r '.rules[].approved' "$approval_temp_file")
        rm -f "$approval_temp_file"

        if [[ "$APPROVAL_STATE" != "true" ]]; then
          log_error "Merge Request !${mr_id} cannot be approved!"
          cleanup_on_failure
          exit 1
        fi
      else
        rm -f "$approval_temp_file"
        log_error "Failed to check approval state!"
        cleanup_on_failure
        exit 1
      fi
    fi

    log_debug "Merge Request !${mr_id} approved!"
  else
    rm -f "$temp_file"
    log_error "Failed to approve Merge Request after retries!"
    cleanup_on_failure
    exit 1
  fi
}

# Wait for merge status to be determined
wait_for_merge_status() {
  local mr_id="$1"

  log_info "Waiting for merge status to be determined"
  local status_retries=0
  local max_status_retries=30

  while [[ $status_retries -lt $max_status_retries ]]; do
    local temp_file
    temp_file=$(mktemp)

    if retry_api_call --header "PRIVATE-TOKEN: $TOKEN" \
      "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}" > "$temp_file"; then

      MR_DETAILED_STATUS=$(jq -r '.detailed_merge_status' "$temp_file")
      rm -f "$temp_file"

      if [[ "$MR_DETAILED_STATUS" != "checking" && \
            "$MR_DETAILED_STATUS" != "preparing" && \
            "$MR_DETAILED_STATUS" != "unchecked" && \
            "$MR_DETAILED_STATUS" != "null" ]]; then
        break
      fi

      log_debug "Current status: ${MR_DETAILED_STATUS}. Waiting... ($((status_retries + 1))/$max_status_retries)"
    else
      log_warn "Failed to fetch merge status. Retrying... ($((status_retries + 1))/$max_status_retries)"
      rm -f "$temp_file"
    fi

    sleep 5
    ((status_retries++))
  done

  if [[ $status_retries -eq $max_status_retries ]]; then
    log_error "Merge status not determined after $max_status_retries attempts. Current status: ${MR_DETAILED_STATUS:-unknown}"
    cleanup_on_failure
    exit 1
  fi

  log_info "Merge status determined: ${MR_DETAILED_STATUS}"
  echo "$MR_DETAILED_STATUS"
}

# Rebase merge request if needed
rebase_merge_request() {
  local mr_id="$1"

  log_info "Merge Request !${mr_id} needs a rebase!"

  # Add retry logic to the rebase API call
  local rebase_response
  local temp_rebase_file
  temp_rebase_file=$(mktemp)

  if ! retry_api_call -X PUT --header "PRIVATE-TOKEN: $TOKEN" \
    "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}/rebase" > "$temp_rebase_file"; then
    log_error "Failed to initiate rebase for Merge Request !${mr_id} after retries"
    rm -f "$temp_rebase_file"
    return 1
  fi

  rebase_response=$(cat "$temp_rebase_file")
  rm -f "$temp_rebase_file"

  MR_REBASE_IN_PROGRESS=$(echo "$rebase_response" | jq -r '.rebase_in_progress')

  # Check if rebase initiation was successful
  if [[ "$MR_REBASE_IN_PROGRESS" != "true" ]]; then
    log_warn "Merge Request !${mr_id} rebase may not have started as expected. Response: $rebase_response"
    log_info "Continuing to monitor rebase status..."
  fi

  # Wait for the rebase to finish
  log_info "Waiting for rebase to complete"
  local rebase_checks=0
  local max_rebase_checks=30
  local consecutive_failures=0
  local max_consecutive_failures=3

  while [[ $rebase_checks -lt $max_rebase_checks ]]; do
    log_debug "Checking rebase status (attempt $((rebase_checks + 1))/$max_rebase_checks)"

    # Add retry logic to status checks
    local temp_file
    temp_file=$(mktemp)
    local status_success=false

    if retry_api_call --header "PRIVATE-TOKEN: $TOKEN" \
      "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}" > "$temp_file"; then

      # Check if the response is valid JSON
      if jq empty "$temp_file" 2>/dev/null; then
        status_success=true
        consecutive_failures=0
      else
        log_warn "Invalid JSON response from GitLab API"
        log_debug "Response content: $(head -c 200 "$temp_file")..."
      fi
    else
      log_warn "Failed to fetch merge request status"
    fi

    if [[ "$status_success" == "false" ]]; then
      ((consecutive_failures++))
      rm -f "$temp_file"

      if [[ $consecutive_failures -ge $max_consecutive_failures ]]; then
        log_error "Too many consecutive API failures ($consecutive_failures). Giving up on rebase check."
        cleanup_on_failure
        exit 1
      fi

      log_info "API call failed, but continuing... (consecutive failures: $consecutive_failures/$max_consecutive_failures)"
      sleep 10
      ((rebase_checks++))
      continue
    fi

    MR_REBASE_IN_PROGRESS=$(jq -r '.rebase_in_progress' "$temp_file")
    MR_MERGE_ERROR=$(jq -r '.merge_error' "$temp_file")
    MR_DETAILED_STATUS=$(jq -r '.detailed_merge_status' "$temp_file")

    # Clean up temp file
    rm -f "$temp_file"

    log_debug "Rebase status - In Progress: ${MR_REBASE_IN_PROGRESS}, Error: ${MR_MERGE_ERROR}, Status: ${MR_DETAILED_STATUS}"

    # Check for successful completion
    if [[ "$MR_REBASE_IN_PROGRESS" == "false" && "$MR_MERGE_ERROR" == "null" && "$MR_DETAILED_STATUS" == "mergeable" ]]; then
      log_info "Rebase for Merge Request !${mr_id} succeeded!"
      return 0
    fi

    # Check for rebase errors
    if [[ "$MR_MERGE_ERROR" != "null" ]]; then
      log_error "Failed to rebase Merge Request !${mr_id}: $MR_MERGE_ERROR"
      cleanup_on_failure
      exit 1
    fi

    # Check if rebase is no longer needed (sometimes status changes)
    if [[ "$MR_DETAILED_STATUS" == "mergeable" && "$MR_REBASE_IN_PROGRESS" != "true" ]]; then
      log_info "Merge Request !${mr_id} is now mergeable (rebase may have completed or wasn't needed)"
      return 0
    fi

    log_debug "Rebase in progress: ${MR_REBASE_IN_PROGRESS}, Status: ${MR_DETAILED_STATUS} ($((rebase_checks + 1))/$max_rebase_checks)"
    sleep 10  # Wait before checking again
    ((rebase_checks++))
  done

  log_error "Rebase did not complete after $max_rebase_checks checks. Current status: ${MR_DETAILED_STATUS:-unknown}"
  cleanup_on_failure
  exit 1
}

# Merge the merge request
merge_request() {
  local mr_id="$1"

  log_info "Merging the Merge Request !${mr_id}"
  local temp_file
  temp_file=$(mktemp)

  if retry_api_call -X PUT --header "PRIVATE-TOKEN: $TOKEN" \
    "${GL_API_URL}/projects/${PROJECT_ID}/merge_requests/${mr_id}/merge" > "$temp_file"; then

    MR_STATE=$(jq -r '.state' "$temp_file")
    rm -f "$temp_file"

    if [[ "$MR_STATE" != "merged" ]]; then
      log_error "Failed to merge Merge Request !${mr_id}"
      cleanup_on_failure
      exit 1
    fi

    log_info "Merge Request !${mr_id} merged successfully!"
  else
    rm -f "$temp_file"
    log_error "Failed to merge Merge Request after retries!"
    cleanup_on_failure
    exit 1
  fi
}

# Main function
main() {
  # Generate unique branch name with timestamp
  NEW_BRANCH="${BRANCH_PREFIX}-$(date "+%Y%m%d%H%M%S")"
  log_info "Starting GitLab MR process"
  log_debug "Project ID: ${PROJECT_ID}"
  log_debug "Target branch: ${TARGET_BRANCH}"
  log_debug "New branch: ${NEW_BRANCH}"

  # Create branch with changes and push
  create_branch_with_changes "$NEW_BRANCH" "$TARGET_BRANCH"
  # Track the created branch for cleanup purposes
  CREATED_BRANCH="$NEW_BRANCH"

  # Create Merge Request
  MR_ID=$(create_merge_request "$NEW_BRANCH" "$TARGET_BRANCH")
  # Track the created MR for cleanup purposes
  CREATED_MR_ID="$MR_ID"

  # Check pipeline status
  log_info "Waiting for pipeline to start"
  PIPELINE_ID=$(wait_for_pipeline_start "$MR_ID")
  check_pipeline_status "$PIPELINE_ID"

  # Approve the Merge Request
  approve_merge_request "$MR_ID"

  # Wait for merge status and get detailed status
  MR_DETAILED_STATUS=$(wait_for_merge_status "$MR_ID")

  # Check if a rebase is needed
  if [[ "$MR_DETAILED_STATUS" == "need_rebase" ]]; then
    rebase_merge_request "$MR_ID"

    # Check pipeline status after rebase
    log_info "Checking pipeline status after rebase"
    PIPELINE_ID=$(wait_for_pipeline_start "$MR_ID")
    check_pipeline_status "$PIPELINE_ID"

    # Re-check merge status after rebase
    MR_DETAILED_STATUS=$(wait_for_merge_status "$MR_ID")
  fi

  # Check if the Merge Request is mergeable
  if [[ "$MR_DETAILED_STATUS" == "mergeable" ]]; then
    merge_request "$MR_ID"
  else
    log_error "Merge Request !${MR_ID} is not mergeable! Status: ${MR_DETAILED_STATUS}"
    cleanup_on_failure
    exit 1
  fi

  log_info "Process completed successfully!"
}

# Parse command line arguments
parse_args "$@"

section_start "create_and_merge_request" "Create and Merge Request" "$COLLAPSED"

# Execute the main function
main

section_end "create_and_merge_request"
