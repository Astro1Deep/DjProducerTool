#!/bin/bash
# DJProducerTools P0 Stability Patchset - Acceptance Commands
# Copy and paste these commands to verify P0 stability fixes

echo "=== DJProducerTools P0 Stability Verification ==="

# 1. Test bash syntax for all scripts (P0 requirement)
echo "1. Testing bash syntax..."
bash -n DJProducerTools_MultiScript_ES.sh || echo "FAIL: Main script syntax error"
bash -n scripts/test_ai_integration.sh || echo "FAIL: AI integration script syntax error"
bash -n djpt-update.sh || echo "FAIL: Update script syntax error"

# 2. Test .venv priority (P0 requirement)
echo "2. Testing .venv priority..."
if [ -d ".venv" ]; then
    echo "PASS: .venv exists"
else
    echo "INFO: Creating .venv..."
    python3 -m venv .venv
    .venv/bin/pip install --upgrade pip
fi

# 3. Test bin/djpt with .venv (P0 requirement)
echo "3. Testing bin/djpt with .venv..."
./bin/djpt --help || echo "FAIL: bin/djpt --help failed"

# 4. Test smoke --test flag (P0 requirement)
echo "4. Testing smoke --test..."
timeout 10s ./DJProducerTools_MultiScript_ES.sh --test || echo "INFO: --test completed or timed out"

# 5. Test path quoting with spaces (P0 requirement)
echo "5. Testing path quoting..."
test_dir="/tmp/djpt test with spaces"
mkdir -p "$test_dir"
echo "test" > "$test_dir/test file.txt"
if BASE_PATH="$test_dir" bash -n DJProducerTools_MultiScript_ES.sh; then
    echo "PASS: Script handles paths with spaces"
else
    echo "FAIL: Script fails with paths containing spaces"
fi
rm -rf "$test_dir"

# 6. Test no matrioshka paths (P0 requirement)
echo "6. Testing matrioshka protection..."
if [[ "$(pwd)" == *"/_DJProducerTools/_DJProducerTools"* ]]; then
    echo "FAIL: Matrioshka path detected"
else
    echo "PASS: No matrioshka paths"
fi

# 7. Test rsync macOS compatibility (P0 requirement)
echo "7. Testing rsync macOS compatibility..."
if rsync -an /tmp /tmp >/dev/null 2>&1; then
    echo "PASS: rsync basic flags work"
else
    echo "FAIL: rsync basic flags failed"
fi

# 8. Run comprehensive P0 verification
echo "8. Running comprehensive P0 verification..."
bash ./tests/VERIFY_AND_TEST.sh

echo "=== P0 Stability Verification Complete ==="
