#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="testclean_$$"
BUILD_SCRIPT="$REPO_ROOT/scripts/build_release_package.sh"
ZIP_PATH="$REPO_ROOT/dist/DJProducerTools_release_${STAMP}.zip"
PACKAGE_ROOT="$REPO_ROOT/dist/DJProducerTools_release_${STAMP}/_DJProducerTools"
trap 'rm -rf "$REPO_ROOT/dist/DJProducerTools_release_${STAMP}" "$ZIP_PATH" "$REPO_ROOT/dist/.validate_DJProducerTools_release_${STAMP}"' EXIT

bash "$BUILD_SCRIPT" "$STAMP" >/dev/null

test -d "$PACKAGE_ROOT"
test -f "$ZIP_PATH"
! test -e "$PACKAGE_ROOT/_DJProducerTools"
! test -e "$PACKAGE_ROOT/state"
! test -e "$PACKAGE_ROOT/logs"
! test -e "$PACKAGE_ROOT/reports"
! test -e "$PACKAGE_ROOT/plans"
! test -e "$PACKAGE_ROOT/quarantine"
! test -e "$PACKAGE_ROOT/shared"
! test -e "$PACKAGE_ROOT/config/djpt.conf"
! zipinfo -1 "$ZIP_PATH" | rg -q '^_DJProducerTools/_DJProducerTools/'
! zipinfo -1 "$ZIP_PATH" | rg -q '^_DJProducerTools/state/'

echo "PASS release_package_clean"
