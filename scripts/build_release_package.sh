#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="${1:-$(date +%Y%m%d_%H%M%S)}"
RELEASE_NAME="DJProducerTools_release_${STAMP}"
RELEASE_PARENT="$REPO_ROOT/dist/$RELEASE_NAME"
PACKAGE_ROOT="$RELEASE_PARENT/_DJProducerTools"
VALIDATE_PARENT="$REPO_ROOT/dist/.validate_${RELEASE_NAME}"
VALIDATE_ROOT="$VALIDATE_PARENT/_DJProducerTools"
ZIP_PATH="$REPO_ROOT/dist/${RELEASE_NAME}.zip"
EXCLUDES_FILE="$REPO_ROOT/release_excludes.lst"
RUN_FRESH_CERT="${DJPT_RELEASE_FRESH_CERT:-1}"
FRESH_NETWORK="${DJPT_RELEASE_FRESH_NETWORK:-0}"
SERAT_ORG_ROOT="$(cd "$REPO_ROOT/.." && pwd)/_SeratOrganizer"
REPORT_PATH="$REPO_ROOT/reports/fresh_install_certification_${STAMP}.md"
SHA256_PATH="${ZIP_PATH}.sha256"
HANDOFF_PATH="$REPO_ROOT/dist/${RELEASE_NAME}_TESTER_HANDOFF.md"

cleanup_validation() {
  rm -rf "$VALIDATE_PARENT"
}

trap cleanup_validation EXIT

mkdir -p "$REPO_ROOT/dist"
rm -rf "$RELEASE_PARENT" "$ZIP_PATH" "$VALIDATE_PARENT"
mkdir -p "$PACKAGE_ROOT" "$VALIDATE_PARENT"

if [ ! -f "$EXCLUDES_FILE" ]; then
  echo "[ERR] Missing release excludes file: $EXCLUDES_FILE" >&2
  exit 1
fi

echo "[INFO] Building clean package root at $PACKAGE_ROOT"
rsync -a --delete --exclude-from="$EXCLUDES_FILE" "$REPO_ROOT/" "$PACKAGE_ROOT/"

if [ -d "$SERAT_ORG_ROOT" ]; then
  echo "[INFO] Including sibling compatibility bundle _SeratOrganizer"
  mkdir -p "$RELEASE_PARENT/_SeratOrganizer"
  rsync -a "$SERAT_ORG_ROOT/" "$RELEASE_PARENT/_SeratOrganizer/"
fi

echo "[INFO] Creating release zip at $ZIP_PATH"
(
  cd "$RELEASE_PARENT"
  if [ -d "_SeratOrganizer" ]; then
    zip -qry "$ZIP_PATH" "_DJProducerTools" "_SeratOrganizer"
  else
    zip -qry "$ZIP_PATH" "_DJProducerTools"
  fi
)

ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$ZIP_SHA256" "$(basename "$ZIP_PATH")" >"$SHA256_PATH"

echo "[INFO] Validating extracted release in $VALIDATE_PARENT"
unzip -q "$ZIP_PATH" -d "$VALIDATE_PARENT"

(
  cd "$VALIDATE_ROOT"
  export BASE_PATH="$VALIDATE_ROOT"
  export DJPT_EXPLICIT_BASE_PATH="$VALIDATE_ROOT"
  bash tests/run_smoke.sh
  bash tests/test_startup_home_and_double_click.sh
  python3 scripts/menu_contract_tools.py validate-json >/dev/null
)

if [ -d "$VALIDATE_ROOT/_DJProducerTools" ]; then
  echo "[ERR] Validation created a nested _DJProducerTools inside the packaged project root." >&2
  exit 1
fi

if [ "$RUN_FRESH_CERT" = "1" ]; then
  echo "[INFO] Fresh-install certifying release from zip"
  CERT_ARGS=(--zip "$ZIP_PATH" --report "$REPORT_PATH")
  if [ "$FRESH_NETWORK" = "1" ]; then
    CERT_ARGS+=(--full-network)
  fi
  bash "$REPO_ROOT/scripts/certify_fresh_install.sh" "${CERT_ARGS[@]}"
fi

bash "$REPO_ROOT/scripts/generate_tester_handoff.sh" \
  --zip "$ZIP_PATH" \
  --checksum "$ZIP_SHA256" \
  --report "$REPORT_PATH" \
  --output "$HANDOFF_PATH"

echo "[OK] Release ready"
echo "PACKAGE_ROOT=$PACKAGE_ROOT"
echo "ZIP_PATH=$ZIP_PATH"
echo "SHA256_PATH=$SHA256_PATH"
echo "HANDOFF_PATH=$HANDOFF_PATH"
