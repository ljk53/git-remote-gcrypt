#!/usr/bin/env bash
# Test: push/clone without pack.packSizeLimit set.
# Ensures the split-pack change doesn't regress default behavior (single pack).
TEST_NAME="No packSizeLimit (default behavior)"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

# Do NOT set pack.packSizeLimit — this is the point of the test.

section_break
echo "Step 1: Create repo with data (~15MB total)"
create_test_repo "${tempdir}/source" 3 2 2621440  # 3 commits × 2 files × 2.5MB
echo "Source repo created." | indent

section_break
echo "Step 2: Push via gitception"
git init --bare -- "${tempdir}/encrypted.git" | indent
(
    cd "${tempdir}/source"
    git push -f "gcrypt::${tempdir}/encrypted.git#${default_branch}" "${default_branch}"
) 2>&1 | indent

section_break
echo "Step 3: Verify encrypted objects"
echo "Object count and sizes:"
list_object_sizes "${tempdir}/encrypted.git"

section_break
echo "Step 4: Clone and verify"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted.git#${default_branch}" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
