#!/usr/bin/env bash

set -e

if [ $# -eq 0 ]; then
    echo "Usage: ./Scripts/run_xcodebuild.sh <xcodebuild args...>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORK_HOME="${XCODEBUILD_WORK_HOME:-/tmp/havital-xcodebuild}"
DERIVED_DATA_DIR="${XCODEBUILD_DERIVED_DATA_DIR:-$WORK_HOME/derivedData}"
TMP_DIR="${XCODEBUILD_TMPDIR:-$WORK_HOME/tmp}"
MODULE_CACHE_DIR="${XCODEBUILD_MODULE_CACHE_DIR:-$WORK_HOME/clang-module-cache}"

mkdir -p "$WORK_HOME" "$DERIVED_DATA_DIR" "$TMP_DIR" "$MODULE_CACHE_DIR"

has_flag() {
    local target="$1"
    shift
    for arg in "$@"; do
        if [ "$arg" = "$target" ]; then
            return 0
        fi
    done
    return 1
}

xcodebuild_args=("$@")

if ! has_flag -derivedDataPath "${xcodebuild_args[@]}"; then
    xcodebuild_args+=("-derivedDataPath" "$DERIVED_DATA_DIR")
fi

if [ -n "${XCODEBUILD_SPM_CLONE_DIR:-}" ]; then
    if ! has_flag -clonedSourcePackagesDirPath "${xcodebuild_args[@]}"; then
        mkdir -p "$XCODEBUILD_SPM_CLONE_DIR"
        xcodebuild_args+=("-clonedSourcePackagesDirPath" "$XCODEBUILD_SPM_CLONE_DIR")
    fi
fi

if [ -n "${XCODEBUILD_SPM_CACHE_DIR:-}" ]; then
    if ! has_flag -packageCachePath "${xcodebuild_args[@]}"; then
        mkdir -p "$XCODEBUILD_SPM_CACHE_DIR"
        xcodebuild_args+=("-packageCachePath" "$XCODEBUILD_SPM_CACHE_DIR")
    fi
fi

if ! has_flag -skipPackageUpdates "${xcodebuild_args[@]}"; then
    xcodebuild_args+=("-skipPackageUpdates")
fi

export HOME="$WORK_HOME"
export TMPDIR="$TMP_DIR"
export XDG_CACHE_HOME="$WORK_HOME/.cache"
export DARWIN_USER_CACHE_DIR="$WORK_HOME/.cache"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

cd "$PROJECT_ROOT"
exec xcodebuild "${xcodebuild_args[@]}"
