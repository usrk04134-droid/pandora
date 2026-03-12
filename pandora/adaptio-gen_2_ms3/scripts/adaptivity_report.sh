#!/usr/bin/env bash

# shellcheck disable=SC2312

set -euo pipefail

# Deterministic number parsing/comparisons, independent of user locale
export LC_ALL=C

usage() {
  cat <<'EOF'
Usage:
  ./adaptivity_report.sh [options]

Options:
  --current_min <float>            Minimum current used in the color scale
  --current_max <float>            Maximum current used in the color scale
  --speed_min   <float>            Minimum speed used in the color scale
  --speed_max   <float>            Maximum speed used in the color scale
  --stickout    <float>            The wire stickout
  --nbr_samples <float>            The number of profiles sampled per weld length
  --macs_rocs_translation <string> Vector in Scilab format defining translation from MACS to ROCS, e.g. "[1;2;3]"
  --quit-on-close                  Shut down Scilab when window is closed
  --help, -h                       Show help

Examples:
  ./adaptivity_report.sh --current_min=200 --quit-on-close
  ./adaptivity_report.sh --macs_rocs_translation "[1; 0; 0]" --speed_min 3.2
EOF
}


LONGOPTS=current_min:,current_max:,speed_min:,speed_max:,stickout:,nbr_samples:,macs_rocs_translation:,quit-on-close,help
PARSED=$(
  getopt \
    --options='h' \
    --longoptions="$LONGOPTS" \
    --name "$0" -- "$@" \
) || { usage; exit 1; }
# Normalize positional parameters to the parsed list
eval set -- "$PARSED"


# ---- Variables only for those we validate in Bash ----
current_min=""; current_max=""
speed_min="";   speed_max=""
stickout="";    nbr_samples=""

# ---- Forward array for Scilab; include only the options present ----
scilab_args=()

# ---- Parsing loop ----
while true; do
  case "$1" in
    --current_min) current_min="$2"; scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --current_max) current_max="$2"; scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --speed_min)   speed_min="$2";   scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --speed_max)   speed_max="$2";   scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --stickout)    stickout="$2";    scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --nbr_samples) nbr_samples="$2"; scilab_args+=( "$1""=""$2" ); shift 2 ;;
    --macs_rocs_translation)
      # We don't need it in Bash; just forward it to Scilab
      scilab_args+=( "$1""=""$2" )
      shift 2
      ;;
    --quit-on-close)
      # Forward flag with no value
      scilab_args+=( "$1" )
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Internal parsing error"; exit 1 ;;
  esac
done

# "$@" now contains any remaining positionals (none expected today)

# ---------- Validation helpers ----------
is_float() {
  # Accepts integers, decimals, scientific notation: 1, -1, 1.0, .5, -0.25, 1e3, -1.2E-03
  [[ "${1:-}" =~ ^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$ ]]
}

validate_optional_float() {
  local name="$1" val="${2:-}"
  [[ -z "$val" ]] && return 0
  if ! is_float "$val"; then
    echo "Error: $name must be a float (got: '$val')" >&2
    exit 1
  fi
}

# Validate floats if provided
validate_optional_float "--current_min" "$current_min"
validate_optional_float "--current_max" "$current_max"
validate_optional_float "--speed_min"   "$speed_min"
validate_optional_float "--speed_max"   "$speed_max"
validate_optional_float "--stickout"    "$stickout"
validate_optional_float "--nbr_samples" "$nbr_samples"

# If both ends of a range are provided, check min ≤ max (using awk for numeric compare)
if [[ -n "$current_min" && -n "$current_max" ]]; then
  if [[ "$(awk -v a="$current_min" -v b="$current_max" 'BEGIN{print (a<=b)?"ok":"bad"}')" != "ok" ]]; then
    echo "Error: --current_min must be <= --current_max" >&2
    exit 1
  fi
fi

if [[ -n "$speed_min" && -n "$speed_max" ]]; then
  if [[ "$(awk -v a="$speed_min" -v b="$speed_max" 'BEGIN{print (a<=b)?"ok":"bad"}')" != "ok" ]]; then
    echo "Error: --speed_min must be <= --speed_max" >&2
    exit 1
  fi
fi

# ---------- Environment & dependencies ----------
export LIBGL_ALWAYS_SOFTWARE=1

if ! command -v scilab >/dev/null 2>&1; then
  echo "Error: 'scilab' not found in PATH." >&2
  echo "Hint: adjust PATH or use a full path (see commented examples below)." >&2
  exit 127
fi

# ---------- Launch Scilab ----------
# We pass the *original* user arguments exactly as given (no re-escaping).
# This ensures things like --macs_rocs_translation "[1; 2; 3]" arrive intact.
scilab -nw -f scripts/simulated_adaptivity_report.sce -args "${scilab_args[@]}"

# Alternative pinned binaries / background variants:
# /usr/bin/scilab-2026.0.0/bin/scilab -nw -f scripts/simulated_adaptivity_report.sce -args "${orig_args[@]}"
# nohup /usr/bin/scilab-2026.0.0/bin/scilab -nw -f scripts/simulated_adaptivity_report.sce -args "${orig_args[@]}" </dev/null >/dev/null 2>&1 &
# /usr/bin/scilab-2026.0.0/bin/scilab -nw -f scripts/simulated_adaptivity_report.sce -args "${orig_args[@]}" > .sci.log &
