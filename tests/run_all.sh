#!/usr/bin/env bash
# Headless test suite runner for Bus Fever Party clone
set -u

TOTAL=0
PASSED=0
FAILED=0
FAILED_TESTS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo "=== Running Bus Fever Party Clone Headless Test Suite ==="
echo "=========================================================="

while IFS= read -r test_path; do
    [ -z "$test_path" ] && continue
    test_file=$(basename "$test_path")
    
    # Skip one-off render scripts
    if [[ "$test_file" == *"render_"* ]]; then
        continue
    fi

    TOTAL=$((TOTAL + 1))
    printf "[%2d] Running tests/%-36s " "$TOTAL" "$test_file..."

    if godot --headless --path "$PROJECT_DIR" --script "res://tests/$test_file" < /dev/null > /tmp/godot_test_last.log 2>&1; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("tests/$test_file")
    fi
done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "test_*.gd" | sort)

echo "=========================================================="
echo "=== Test Suite Summary: $PASSED / $TOTAL Passed ($FAILED Failed) ==="
echo "=========================================================="

if [ $FAILED -gt 0 ]; then
    echo "Failing tests:"
    for ft in "${FAILED_TESTS[@]}"; do
        echo "  - $ft"
    done
    exit 1
fi

# Reset persistent test coins so user profile always starts at 0 coins
SAVE_CFG="$HOME/Library/Application Support/Godot/app_userdata/Bus Fever Party Clone/save.cfg"
if [ -f "$SAVE_CFG" ]; then
    sed -i '' 's/^coins=.*/coins=0/' "$SAVE_CFG" 2>/dev/null || true
fi

echo "All headless tests passed successfully!"
exit 0
