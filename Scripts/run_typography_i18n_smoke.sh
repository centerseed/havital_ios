#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=${DEVICE_NAME},OS=26.5}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build/typography-i18n}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PROJECT_ROOT}/build/typography-i18n-artifacts}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.havital.Havital.dev}"

SCREENS=(
  "login"
  "tab_entry"
  "performance"
  "profile"
  "training_home"
  "week_timeline"
)

LOCALES=(
  "en:en_US"
  "ja:ja_JP"
  "zh-Hant:zh_TW"
)

mkdir -p "${BUILD_DIR}" "${ARTIFACT_DIR}"

build_args=(
  -project "${PROJECT_ROOT}/Havital.xcodeproj"
  -scheme Havital
  -configuration "${CONFIGURATION}"
  -destination "${DESTINATION}"
  build
)

if [[ -n "${DERIVED_DATA_PATH}" ]]; then
  build_args+=(-derivedDataPath "${DERIVED_DATA_PATH}")
fi

xcodebuild \
  "${build_args[@]}"

if [[ -n "${DERIVED_DATA_PATH}" ]]; then
  APP_SEARCH_ROOT="${DERIVED_DATA_PATH}/Build/Products"
else
  APP_SEARCH_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"
fi

APP_PATH="$(find "${APP_SEARCH_ROOT}" -path "*/${CONFIGURATION}-iphonesimulator/paceriz_dev.app" -type d -print -quit)"
if [[ -z "${APP_PATH}" ]]; then
  echo "Unable to locate built paceriz_dev.app under ${APP_SEARCH_ROOT}" >&2
  exit 1
fi

xcrun simctl boot "${DEVICE_NAME}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${DEVICE_NAME}" -b
xcrun simctl install "${DEVICE_NAME}" "${APP_PATH}"

for locale_pair in "${LOCALES[@]}"; do
  language="${locale_pair%%:*}"
  apple_locale="${locale_pair##*:}"

  for screen in "${SCREENS[@]}"; do
    output_dir="${ARTIFACT_DIR}/${language}"
    mkdir -p "${output_dir}"

    xcrun simctl terminate "${DEVICE_NAME}" "${APP_BUNDLE_ID}" >/dev/null 2>&1 || true
    SIMCTL_CHILD_UITEST_TYPOGRAPHY_SCREEN="${screen}" \
      xcrun simctl launch \
        --terminate-running-process \
        "${DEVICE_NAME}" \
        "${APP_BUNDLE_ID}" \
        -ui_testing \
        -ui_testing_typography_audit \
        -ui_testing_skip_notification_authorization \
        -AppleLanguages "(${language})" \
        -AppleLocale "${apple_locale}" >/dev/null

    sleep 5
    xcrun simctl io "${DEVICE_NAME}" screenshot "${output_dir}/${screen}.png" >/dev/null
    echo "Captured ${output_dir}/${screen}.png"
  done
done

echo "Typography i18n smoke screenshots: ${ARTIFACT_DIR}"
