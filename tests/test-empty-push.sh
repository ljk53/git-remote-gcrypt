#!/usr/bin/env bash
# Test: pushing when there are no new objects.
# Push the same thing twice — second push should succeed without errors.
TEST_NAME="Empty push (no new objects)"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create repo"
create_test_repo "${tempdir}/source" 2 1 1048576  # 2 commits × 1 file × 1MB
echo "Source repo created." | indent

section_break
echo "Step 2: First push"
git init --bare -- "${tempdir}/encrypted.git" | indent
(
    cd "${tempdir}/source"
    git remote add cryptremote "gcrypt::${tempdir}/encrypted.git#${default_branch}"
    git push -f cryptremote "${default_branch}"
) 2>&1 | indent

count1=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count after first push: ${count1}"

section_break
echo "Step 3: Second push (no changes — should be a no-op)"
(
    cd "${tempdir}/source"
    git push -f cryptremote "${default_branch}"
) 2>&1 | indent

count2=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count after second push: ${count2}"

# Object count should not change
[[ ${count1} -eq ${count2} ]] || fail "Object count changed on empty push (${count1} -> ${count2})"
pass "Object count unchanged: ${count1}"

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
