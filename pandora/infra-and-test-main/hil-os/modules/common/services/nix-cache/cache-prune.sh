#!/usr/bin/env bash

# Enable strict mode
set -uo pipefail

# Define error codes
ERR_COMMAND_FAILED=1
ERR_CACHE_DIR_MISSING=2
ERR_PERMISSION_DENIED=3
ERR_INTERRUPTED=130

# Default values
DEFAULT_CACHE_DIR="${NIX_STORED_PATH:-/var/lib/nix-stored}"
DEFAULT_LOG_LEVEL="INFO"

# Function to print usage
usage() {
  echo "Usage: sudo $0 [OPTIONS]"
  echo ""
  echo "NOTE: This script requires root privileges to access the nix-stored cache directory"
  echo ""
  echo "Options:"
  echo "  --cache-dir <path>    Path to the nix-stored cache directory (default: \$NIX_STORED_PATH or $DEFAULT_CACHE_DIR)"
  echo "  --log-level <level>   Log level: DEBUG, INFO, WARN, ERROR (default: $DEFAULT_LOG_LEVEL)"
  echo "  --dry-run             Show what would be deleted without actually deleting"
  echo "  --restart-service     Restart nix-stored service after cleanup (default: enabled)"
  echo "  --help                Show this help message"
  echo ""
  echo "Examples:"
  echo "  sudo $0                                     # Clean default cache directory and restart service"
  echo "  sudo $0 --cache-dir /custom/path            # Clean custom directory"
  echo "  sudo $0 --dry-run                           # Show what would be deleted"
  echo "  sudo $0 --log-level DEBUG                   # Enable debug logging"
  echo ""
  exit $ERR_COMMAND_FAILED
}

# Function to log messages with different levels
log() {
  local log_level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Only show messages at or above the current log level
  case "$LOG_LEVEL" in
    "DEBUG") allowed_levels="DEBUG INFO WARN ERROR" ;;
    "INFO")  allowed_levels="INFO WARN ERROR" ;;
    "WARN")  allowed_levels="WARN ERROR" ;;
    "ERROR") allowed_levels="ERROR" ;;
  esac

  case " $allowed_levels " in
    *" $log_level "*) 
      echo "[$timestamp] [$log_level] $message" ;;
  esac
}

# Function to handle errors
handle_error() {
  local err_code="$1"
  local message="$2"
  
  case "$err_code" in
    "$ERR_COMMAND_FAILED")
      log "ERROR" "Command failed: $message"
      ;;
    "$ERR_CACHE_DIR_MISSING")
      log "ERROR" "Cache directory error: $message"
      ;;
    "$ERR_PERMISSION_DENIED")
      log "ERROR" "Permission denied: $message"
      ;;
    "$ERR_INTERRUPTED")
      log "ERROR" "Operation was interrupted: $message"
      ;;
    *)
      log "ERROR" "Unknown error occurred with code $err_code: $message"
      ;;
  esac
  exit "$err_code"
}

# Function to validate inputs
validate_inputs() {
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    handle_error "$ERR_PERMISSION_DENIED" "This script must be run as root or with sudo to access the nix-stored cache directory"
  fi

  if [[ ! -e "$CACHE_DIR" ]]; then
    handle_error "$ERR_CACHE_DIR_MISSING" "Cache directory does not exist: $CACHE_DIR"
  fi

  if [[ "$RESTART_SERVICE" == "true" ]] && ! command -v systemctl &> /dev/null; then
    handle_error "$ERR_COMMAND_FAILED" "systemctl not found but --restart-service was requested"
  fi
}

# Function to get directory size
get_directory_size() {
  local dir="$1"
  if [[ -e "$dir" ]]; then
    du -shL "$dir" 2>/dev/null | cut -f1 || echo "unknown"
  else
    echo "0"
  fi
}

# Function to count files and directories
count_cache_contents() {
  local dir="$1"
  local files=0
  local dirs=0

  if [[ -d "$dir" ]]; then
    files=$(find "$dir" -mindepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l || echo "0")
    dirs=$(find "$dir" -mindepth 1 -type d 2>/dev/null | wc -l || echo "0")
  fi

  echo "$files $dirs"
}

# Function to perform the cache cleanup
cleanup_cache() {
  log "INFO" "Starting nix-stored cache cleanup..."
  log "INFO" "Cache directory: $CACHE_DIR"

  # Check if the cache directory exists (could be a symlink)
  if [[ ! -e "$CACHE_DIR" ]]; then
    log "WARN" "Cache directory does not exist, nothing to clean"
    return 0
  fi

  local real_cache_dir
  real_cache_dir=$(readlink -f "$CACHE_DIR") || handle_error "$ERR_COMMAND_FAILED" "Failed to resolve cache directory path: $CACHE_DIR"

  log "INFO" "Working with directory: $real_cache_dir"

  # Get current cache size before cleanup
  local current_size
  current_size=$(get_directory_size "$CACHE_DIR")
  log "INFO" "Current cache size: $current_size"

  # Count total files and directories
  local counts
  counts=$(count_cache_contents "$real_cache_dir")
  local total_files
  total_files=$(echo "$counts" | cut -d' ' -f1)
  local total_dirs
  total_dirs=$(echo "$counts" | cut -d' ' -f2)

  log "INFO" "Found $total_files files/symlinks and $total_dirs directories in cache"

  if [[ "$total_files" -gt 0 || "$total_dirs" -gt 0 ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "INFO" "[DRY RUN] Would remove all cache contents ($total_files files/symlinks, $total_dirs directories)"
      log "INFO" "[DRY RUN] Would restart nix-stored service after cleanup"
      log "INFO" "[DRY RUN] Cache cleanup completed (simulation)"
    else
      log "INFO" "Completely clearing all cached data..."

      # Remove all files, symlinks, and directories in the real cache directory
      if find "$real_cache_dir" -mindepth 1 -delete 2>/dev/null; then
        log "INFO" "Removed all cache contents ($total_files files/symlinks, $total_dirs directories)"
        log "INFO" "Cache completely cleared"

        # Always restart service after successful cleanup
        log "INFO" "Restarting nix-stored service after cache cleanup..."
        if systemctl restart nix-stored.service 2>/dev/null; then
          log "INFO" "nix-stored service restarted successfully"
        else
          log "WARN" "Failed to restart nix-stored service - you may need to restart it manually"
        fi
      else
        handle_error "$ERR_PERMISSION_DENIED" "Failed to delete cache contents - check permissions"
      fi
    fi
  else
    log "INFO" "Cache is already empty, nothing to clean"
  fi
}

# Function to check command line arguments
check_arg() {
  local arg_name="$1"
  local arg_value="$2"
  if [[ -z "${arg_value:-}" || "${arg_value:0:2}" == "--" ]]; then
    log "ERROR" "Missing value for ${arg_name}"
    usage
  fi
}

# Initialize default values
CACHE_DIR="$DEFAULT_CACHE_DIR"
LOG_LEVEL="$DEFAULT_LOG_LEVEL"
DRY_RUN="false"
RESTART_SERVICE="true"  # Always restart service after cleanup by default

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --cache-dir)
      check_arg "--cache-dir" "${2:-}"
      CACHE_DIR="$2"; shift ;;
    --log-level)
      check_arg "--log-level" "${2:-}"
      LOG_LEVEL="$2"; shift ;;
    --dry-run)
      DRY_RUN="true" ;;
    --restart-service)
      RESTART_SERVICE="true" ;;
    --help) 
      usage ;;
    *) 
      log "ERROR" "Unknown option: $1"
      usage ;;
  esac
  shift
done

# Validate inputs
validate_inputs

# Trap interruption signals
trap 'handle_error $ERR_INTERRUPTED "Script was interrupted"' INT TERM

# Main execution
log "INFO" "=== Nix Cache Cleanup Script Started ==="
log "DEBUG" "Configuration:"
log "DEBUG" "  Cache Directory: $CACHE_DIR"
log "DEBUG" "  Log Level: $LOG_LEVEL"
log "DEBUG" "  Dry Run: $DRY_RUN"
log "DEBUG" "  Restart Service: $RESTART_SERVICE"

cleanup_cache

log "INFO" "=== Nix Cache Cleanup Script Completed Successfully ==="
