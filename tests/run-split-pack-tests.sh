#!/usr/bin/env bash
# Run all split-pack test scenarios.
set -eu
cd "$(dirname "$0")"

tests=(
    test-no-size-limit.sh
    test-tiny-pack-limit.sh
    test-incremental-push.sh
    test-full-repack.sh
    test-empty-push.sh
    test-local-backend.sh
)

passed=0
failed=0
failed_tests=()

for t in "${tests[@]}"; do
    echo ""
    echo "###################################################################"
    echo "# Running: ${t}"
    echo "###################################################################"
    if bash "${t}"; then
        passed=$(( passed + 1 ))
    else
        failed=$(( failed + 1 ))
        failed_tests+=("${t}")
    fi
done

echo ""
echo "==================================================================="
echo "Results: ${passed} passed, ${failed} failed out of ${#tests[@]}"
if [[ ${failed} -gt 0 ]]; then
    echo "Failed tests:"
    for t in "${failed_tests[@]}"; do
        echo "  - ${t}"
    done
    exit 1
fi
echo "All tests passed!"
