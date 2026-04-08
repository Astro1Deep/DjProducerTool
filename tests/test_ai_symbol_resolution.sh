#!/usr/bin/env bash
# Regression: detect unresolved action/submenu/ensure/install symbols in canonical script.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -f "$APP_SCRIPT" ]; then
  printf "[FAIL] canonical script not found: %s\n" "$APP_SCRIPT"
  exit 1
fi

python3 - "$APP_SCRIPT" <<'PY'
import re
import sys
from pathlib import Path

script_path = Path(sys.argv[1])
text = script_path.read_text(encoding="utf-8", errors="ignore")

defs = set(re.findall(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{', text, re.MULTILINE))
calls = {}
token_re = re.compile(r'\b(action_[A-Za-z0-9_]+|submenu_[A-Za-z0-9_]+|ensure_[A-Za-z0-9_]+|install_[A-Za-z0-9_]+)\b')

for lineno, line in enumerate(text.splitlines(), 1):
    stripped = line.strip()
    if stripped.startswith("#"):
        continue
    for match in token_re.finditer(line):
        token = match.group(1)
        if re.match(r'^\s*' + re.escape(token) + r'\s*\(\)\s*\{', line):
            continue
        calls.setdefault(token, lineno)

allowlist = {
    "install_serato_opt",  # variable token (not a function)
    "ensure_ascii",  # json.dump keyword inside embedded Python snippets
}
missing = sorted(token for token in calls if token not in defs and token not in allowlist)

if missing:
    print("[FAIL] unresolved symbols detected:")
    for token in missing:
        print(f"  - {token} (line ~{calls[token]})")
    sys.exit(1)

required_defs = {
    "action_ai_backend_supermenu",
    "submenu_T_tensorflow_lab",
    "ensure_python_package_installed",
}
missing_required = sorted(name for name in required_defs if name not in defs)
if missing_required:
    print("[FAIL] required symbols missing:")
    for name in missing_required:
        print(f"  - {name}")
    sys.exit(1)

print("[PASS] AI symbol resolution check passed")
PY
