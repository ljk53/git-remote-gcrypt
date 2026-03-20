#!/usr/bin/env bash
# Test: local path backend (not gitception).
# Uses a plain directory (not a git repo) as remote — different PUT/GET code path.
TEST_NAME="Local path backend with split packs"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create repo (~10MB)"
create_test_repo "${tempdir}/source" 2 2 2621440
echo "Source repo created." | indent

section_break
echo "Step 2: Push to local path (NOT a bare git repo)"
# Create a plain directory — triggers local path backend instead of gitception.
mkdir -p "${tempdir}/encrypted-local"
(
    cd "${tempdir}/source"
    git remote add cryptlocal "gcrypt::${tempdir}/encrypted-local"
    git push -f cryptlocal "${default_branch}"
) 2>&1 | indent

echo "Files in encrypted remote:"
list_object_sizes "${tempdir}/encrypted-local"
file_count=$(find "${tempdir}/encrypted-local" -type f | wc -l)
echo "File count: ${file_count}"

section_break
echo "Step 3: Check that no single file exceeds 5MB (roughly)"
large_files=$(find "${tempdir}/encrypted-local" -type f -size +6M | wc -l)
if [[ ${large_files} -gt 0 ]]; then
    echo "Large files found:"
    find "${tempdir}/encrypted-local" -type f -size +6M -exec du -sh {} + | indent
    fail "Found ${large_files} files larger than 6MB despite 5m pack limit"
fi
pass "No oversized files"

section_break
echo "Step 4: Clone from local path and verify"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted-local" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "Step 5: Incremental push to local path"
(
    cd "${tempdir}/source"
    head -c 2621440 /dev/urandom > "extra.data"
    git add .
    git commit -m "Extra commit"
    git push -f cryptlocal "${default_branch}"
) 2>&1 | indent

echo "Files after incremental push:"
list_object_sizes "${tempdir}/encrypted-local"

section_break
echo "Step 6: Clone again and verify with extra commit"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted-local" -- \
        "${tempdir}/cloned2"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned2"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
