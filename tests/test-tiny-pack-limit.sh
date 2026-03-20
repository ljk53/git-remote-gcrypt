#!/usr/bin/env bash
# Test: extremely small packSizeLimit (1m) forcing many splits.
# Verifies correctness with a large number of small pack files.
TEST_NAME="Tiny packSizeLimit (1m) — many splits"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 1m

section_break
echo "Step 1: Create repo (~15MB total, expect ~15+ packs)"
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
echo "Step 3: Verify many small objects were created"
echo "Object sizes:"
list_object_sizes "${tempdir}/encrypted.git"
count=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count: ${count}"

# With 1m limit and ~15MB data, we expect more than a few packs
# (manifest + multiple encrypted packs)
[[ ${count} -gt 5 ]] || fail "Expected many objects with 1m limit, got ${count}"
pass "Got ${count} objects (many splits as expected)"

section_break
echo "Step 4: Clone and verify data integrity"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted.git#${default_branch}" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
