#!/usr/bin/env bash
# ==============================================================================
# This script is designed to be run in a GitLab CI/CD pipeline.
# It deploys a NixOS on a remote system using `nixos-rebuild boot` and checks
# the status of the system after reboot.
#
# It has the following requirements on the environment:
#   - bash must be installed
#   - git must be installed
#   - sshpass must be installed
#   - nix must be installed and support for flakes must be enabled
#   - the logger module must be available in the same directory as this script
#   - version.txt file from the adaptio-os repository must be present
# ==============================================================================

# Exit on error, undefined variables, or pipe failures
set -euo pipefail

# Source the logger module
# Assuming the logger is in the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

readonly ADAPTIO_CONFIG_YAML="/var/lib/adaptio/configuration.yaml"
readonly TEMP_SUDOERS_MARKER_BEGIN="# ADAPTIO_CI_NOPASSWD_BEGIN"
readonly TEMP_SUDOERS_MARKER_END="# ADAPTIO_CI_NOPASSWD_END"

# Default configuration values
REMOTE_USER="esab"
SERVICE_NAME="adaptio.service"
MAX_RECONNECT_ATTEMPTS=30
MAX_SERVICE_CHECK_ATTEMPTS=6
COLLAPSED="true"
IMAGE_SIMULATION=0

# Help function
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy to a remote NixOS system using nixos-rebuild boot.

Options:
  -u, --user USER              Remote username (default: $REMOTE_USER)
  -t, --target HOST            Target host IP or hostname (required)
  -f, --flake FLAKE_ATTR       Flake attribute to build (required)
  -s, --service SERVICE        Service to check after deployment (default: $SERVICE_NAME)
  -p, --password PASS          SSH password (required)
  -r, --reconnect-attempts N   Maximum reconnection attempts (default: $MAX_RECONNECT_ATTEMPTS)
  -c, --check-attempts N       Maximum service check attempts (default: $MAX_SERVICE_CHECK_ATTEMPTS)
  -i, --image-simulation       Enable simulation of image provider (default: disabled)
  -v, --verbose                Enable verbose output
  -q, --quiet                  Suppress all output except for errors
  --section-expanded           Start with expanded section(s)
  -h, --help               Show this help message and exit

Example:
  $(basename "$0") --user esab --target 10.0.0.10 --flake .#myhost --service myapp.service --password secret
EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -u|--user)
        REMOTE_USER="$2"
        shift 2
        ;;
      -t|--target)
        TARGET_HOST="$2"
        shift 2
        ;;
      -f|--flake)
        FLAKE_ATTR="$2"
        shift 2
        ;;
      -s|--service)
        SERVICE_NAME="$2"
        shift 2
        ;;
      -p|--password)
        REMOTE_PASSWORD="$2"
        shift 2
        ;;
      -r|--reconnect-attempts)
        MAX_RECONNECT_ATTEMPTS="$2"
        shift 2
        ;;
      -c|--check-attempts)
        MAX_SERVICE_CHECK_ATTEMPTS="$2"
        shift 2
        ;;
      -i|--image-simulation)
        IMAGE_SIMULATION=1
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
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  # Check required arguments
  if [[ -z ${FLAKE_ATTR:-} || -z ${REMOTE_PASSWORD:-} || -z ${TARGET_HOST:-} ]]; then
    log_error "Missing required arguments!"
    show_help
    exit 1
  fi
}

run_remote_command() {
  local command="$1"

  nix shell nixpkgs#sshpass --command sshpass -e \
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$TARGET_HOST" \
    "sudo -S $command" <<< "$SSHPASS"
}

enable_temporary_passwordless_sudo() {
  log_warn "⚠️  Enabling temporary passwordless sudo for $REMOTE_USER"

  run_remote_command "bash -c \"if ! grep -q \\\"$TEMP_SUDOERS_MARKER_BEGIN\\\" /etc/sudoers; then printf '%s\\n' \\\"$TEMP_SUDOERS_MARKER_BEGIN\\\" \\\"$REMOTE_USER ALL=(ALL) NOPASSWD: ALL\\\" \\\"$TEMP_SUDOERS_MARKER_END\\\" >> /etc/sudoers; fi\""
  run_remote_command "visudo -cf /etc/sudoers"

  log_info "✅ Temporary passwordless sudo enabled"
}

disable_temporary_passwordless_sudo() {
  log_info "🧹 Removing temporary passwordless sudo configuration"
  run_remote_command "bash -c \"if grep -q \\\"$TEMP_SUDOERS_MARKER_BEGIN\\\" /etc/sudoers; then sed -i \\\"/$TEMP_SUDOERS_MARKER_BEGIN/,/$TEMP_SUDOERS_MARKER_END/d\\\" /etc/sudoers; fi\"" || true
}

wait_for_host_to_come_back() {
  log_info "⏳ Waiting for $TARGET_HOST to come back online..."
  local attempt=1

  # Give the system time to fully reboot
  log_info "Initial wait for system to reboot (20 seconds)..."
  sleep 20

  while [ "$attempt" -le "$MAX_RECONNECT_ATTEMPTS" ]; do
    log_debug "Connection attempt $attempt/$MAX_RECONNECT_ATTEMPTS..."

    # Use simple connection test with nixpkgs
    if nix shell nixpkgs#sshpass --command sshpass -e \
         ssh -o ConnectTimeout=5 \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
         -o LogLevel=ERROR \
         "${REMOTE_USER}@${TARGET_HOST}" \
         'echo "Connection successful"' >/dev/null 2>&1; then

      log_info "✅ $TARGET_HOST is back online with working SSH."
      return 0
    else
      log_debug "SSH connection attempt failed. Retrying in 5 seconds..."
    fi

    sleep 5
    ((attempt++))
  done

  log_error "❌ Failed to connect to $TARGET_HOST after $MAX_RECONNECT_ATTEMPTS attempts"
  return 1
}

check_service_status() {
  local service="$1"
  local attempt=1

  log_info "🔍 Checking status of service: $service"

  while [ "$attempt" -le "$MAX_SERVICE_CHECK_ATTEMPTS" ]; do
    log_debug "Service check attempt $attempt/$MAX_SERVICE_CHECK_ATTEMPTS..."

    # Get service status using run_remote_command
    local status_output
    status_output=$(run_remote_command "systemctl status $service") || true

    # Check if service is active and running
    if echo "$status_output" | grep -q "Active: active (running)"; then
      log_info "✅ Service $service is active and running"
      echo "$status_output"  # Display full status
      return 0
    else
      log_warn "Service not fully active yet. Current status:"
      # Show Active line if present, otherwise show first few lines
      echo "$status_output" | grep -E "Active:" || echo "$status_output" | head -n 5 || echo "Could not determine status"
      log_debug "Waiting 10 seconds before retrying..."
    fi

    sleep 10
    ((attempt++))
  done

  log_error "❌ Service $service failed to start properly after $MAX_SERVICE_CHECK_ATTEMPTS attempts"
  return 1
}

# Function to check if deployed version matches expected version
verify_adaptio_os_version() {
  log_info "🔍 Verifying Adaptio OS version..."

  # Read expected version from version.txt
  if [[ ! -f "version.txt" ]]; then
    log_error "❌ version.txt file not found in the current directory"
    return 1
  fi

  local expected_version
  expected_version=$(tr -d '[:space:]' < version.txt)

  # Get deployed version from remote system env
  local deployed_version
  deployed_version=$(run_remote_command "echo \"\$ADAPTIO_OS_VERSION\"")

  if [[ -z "$deployed_version" ]]; then
    log_error "❌ ADAPTIO_OS_VERSION not found on the remote system"
    return 1
  fi

  deployed_version=$(echo "$deployed_version" | tr -d '[:space:]' | sed 's/-dev$//')

  log_info "Expected version: $expected_version"
  log_info "Deployed version: $deployed_version"

  if [[ "$deployed_version" != "$expected_version" ]]; then
    log_error "❌ Version mismatch! Expected: $expected_version, Got: $deployed_version"
    return 1
  else
    log_info "✅ Adaptio OS version verified successfully: $deployed_version"
    return 0
  fi
}

# Function to deploy using nixos-rebuild boot
do_rebuild_with_boot() {
  local rebuild_output
  local temp_sudo_enabled=0

  cleanup_rebuild_sudo() {
    if [[ "${temp_sudo_enabled:-0}" -eq 1 ]]; then
      disable_temporary_passwordless_sudo
    fi
  }

  trap cleanup_rebuild_sudo RETURN

  log_info "📦 Running nixos-rebuild boot on $TARGET_HOST..."
  enable_temporary_passwordless_sudo
  temp_sudo_enabled=1

  if rebuild_output=$(nix shell nixpkgs#sshpass --command sshpass -e nix run nixpkgs#nixos-rebuild -- boot \
  --sudo \
  --target-host "$REMOTE_USER@$TARGET_HOST" \
  --flake "$FLAKE_ATTR"); then
    log_info "✅ Successfully completed nixos-rebuild with boot"
    return 0
  fi

  echo "$rebuild_output"

  log_error "❌ Failed to complete nixos-rebuild with boot"
  return 1
}

create_simulation_config() {
  local temp_config
  temp_config=$(mktemp) || {
    log_error "Failed to create temporary file"
    return 1
  }

  cat > "$temp_config" <<EOF
image_provider:
  type: simulation
  simulation:
    realtime: false
    images: .
EOF

  echo "$temp_config"
}

deploy_simulation_config() {
  local config_file
  config_file=$(create_simulation_config) || return 1

  log_info "Transferring configuration file to $TARGET_HOST..."

  if nix shell nixpkgs#sshpass --command sshpass -e \
       scp -q \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           "$config_file" \
           "$REMOTE_USER@$TARGET_HOST:/tmp/adaptio_config.yaml" 2>/dev/null; then

    # Move to final location
    run_remote_command "sudo mv /tmp/adaptio_config.yaml $ADAPTIO_CONFIG_YAML"
    log_info "✅ Configuration file deployed successfully"
  else
    log_error "❌ Failed to transfer configuration file"
    rm -f "$config_file"
    return 1
  fi

  # Cleanup
  rm -f "$config_file"
}

# Main deployment process
main() {
  # Print current configuration
  log_debug "Deployment configuration:"
  log_debug "- Remote user: $REMOTE_USER"
  log_debug "- Target host: $TARGET_HOST"
  log_debug "- Flake attribute: $FLAKE_ATTR"
  log_debug "- Service name: $SERVICE_NAME"
  log_debug "- Max reconnect attempts: $MAX_RECONNECT_ATTEMPTS"
  log_debug "- Max service check attempts: $MAX_SERVICE_CHECK_ATTEMPTS"

  # Export password for sshpass
  export SSHPASS="$REMOTE_PASSWORD"

  # Check for SSHPASS
  if [[ -z "${SSHPASS:-}" ]]; then
    log_error "Error: SSH password is not set."
    exit 1
  fi

  section_start "rebuild_with_boot" "Rebuild Adaptio OS with boot" "$COLLAPSED"
  # Step 1: Deploy with `boot` (sets next boot config)
  if ! do_rebuild_with_boot; then
    exit 1
  fi
  section_end "rebuild_with_boot"

  # Update configuration.yaml to enable simulation of the image provider, i.e., no scanner/camera connected
  if [[ $IMAGE_SIMULATION -eq 1 ]]; then
    section_start "enable_image_simulation" "Enable simulation of image provider" "$COLLAPSED"
    deploy_simulation_config
    section_end "enable_image_simulation"
  fi

  section_start "reboot_system" "Reboot and wait for system to come back online" "$COLLAPSED"
  # Step 2: Reboot target using run_remote_command
  log_info "🔄 Rebooting $TARGET_HOST..."
  run_remote_command "reboot" || true

  # Step 3: Wait for target to come back online
  if ! wait_for_host_to_come_back; then
    log_error "❌ Deployment failed: couldn't reconnect to host after reboot"
    exit 1
  fi
  section_end "reboot_system"

  section_start "check_system_status" "Check system status" "$COLLAPSED"
  # Step 4: Check service status and wait until it's running
  if ! check_service_status "$SERVICE_NAME"; then
    log_error "❌ Deployment failed: service $SERVICE_NAME is not running properly"
    exit 1
  fi
  section_end "check_system_status"

  section_start "verify_adaptio_os_version" "Verify Adaptio OS version" "$COLLAPSED"
  # Step 5: Verify that the deployed OS version matches the expected version
  if ! verify_adaptio_os_version; then
    log_error "❌ Deployment failed: incorrect Adaptio OS version deployed"
    exit 1
  fi
  section_end "verify_adaptio_os_version"

  log_info "✅ Deployment process completed successfully"
}

# Parse command line arguments
parse_args "$@"

section_start "deploy_adaptio_os" "Deploy Adaptio OS" "$COLLAPSED"

# Execute the main function
main

section_end "deploy_adaptio_os"
