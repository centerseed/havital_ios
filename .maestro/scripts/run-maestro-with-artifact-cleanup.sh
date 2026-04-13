#!/usr/bin/env bash

set -euo pipefail

ARTIFACT_ROOT="${MAESTRO_ARTIFACT_ROOT:-$HOME/.maestro/tests}"
MAESTRO_BIN="${MAESTRO_BIN:-$HOME/.maestro/bin/maestro}"
MAESTRO_REINSTALL_DRIVER="${MAESTRO_REINSTALL_DRIVER:-0}"

usage() {
  cat <<'EOF'
Usage:
  run-maestro-with-artifact-cleanup.sh test <maestro args...>
  run-maestro-with-artifact-cleanup.sh cleanup-existing

Behavior:
  - On passing runs, delete all screenshot PNGs in the new artifact directory.
  - On failing runs, keep only screenshot-❌-*.png as evidence and delete warning screenshots.
  - Always keep ai-report/html/json/log files.
EOF
}

list_artifact_dirs() {
  find "$ARTIFACT_ROOT" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

cleanup_artifact_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  local total_png
  total_png=$(find "$dir" -maxdepth 1 -type f -name 'screenshot-*.png' | wc -l | tr -d ' ')
  [ "$total_png" -gt 0 ] || return 0

  if find "$dir" -maxdepth 1 -type f -name 'screenshot-❌-*.png' | grep -q .; then
    find "$dir" -maxdepth 1 -type f -name 'screenshot-*.png' ! -name 'screenshot-❌-*.png' -delete
    local kept
    kept=$(find "$dir" -maxdepth 1 -type f -name 'screenshot-❌-*.png' | wc -l | tr -d ' ')
    echo "artifact-cleanup: kept $kept failure screenshot(s) in $dir"
  else
    find "$dir" -maxdepth 1 -type f -name 'screenshot-*.png' -delete
    echo "artifact-cleanup: removed $total_png screenshot(s) from $dir"
  fi
}

cleanup_existing() {
  local dir
  while IFS= read -r dir; do
    cleanup_artifact_dir "$ARTIFACT_ROOT/$dir"
  done < <(list_artifact_dirs)
}

run_test_with_cleanup() {
  mkdir -p "$ARTIFACT_ROOT"

  local before_file after_file
  before_file="$(mktemp)"
  after_file="$(mktemp)"

  list_artifact_dirs > "$before_file"

  set +e
  if [ "$MAESTRO_REINSTALL_DRIVER" = "1" ]; then
    "$MAESTRO_BIN" test "$@"
  else
    "$MAESTRO_BIN" test --no-reinstall-driver "$@"
  fi
  local status=$?
  set -e

  list_artifact_dirs > "$after_file"

  local new_dirs
  new_dirs="$(comm -13 "$before_file" "$after_file" || true)"

  if [ -n "$new_dirs" ]; then
    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      cleanup_artifact_dir "$ARTIFACT_ROOT/$dir"
    done <<< "$new_dirs"
  else
    local latest_dir
    latest_dir="$(find "$ARTIFACT_ROOT" -mindepth 1 -maxdepth 1 -type d -exec stat -f '%m %N' {} \; | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
    [ -n "$latest_dir" ] && cleanup_artifact_dir "$latest_dir"
  fi

  rm -f "$before_file" "$after_file"

  return "$status"
}

main() {
  [ $# -gt 0 ] || { usage; exit 1; }

  case "$1" in
    test)
      shift
      [ $# -gt 0 ] || { usage; exit 1; }
      run_test_with_cleanup "$@"
      ;;
    cleanup-existing)
      cleanup_existing
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
