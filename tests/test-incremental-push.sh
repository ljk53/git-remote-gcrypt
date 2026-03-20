#!/usr/bin/env bash
# Test: incremental push — push once, add more commits, push again.
# Verifies that new packs coexist with old packs in the manifest.
TEST_NAME="Incremental push with split packs"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create initial repo (~10MB)"
create_test_repo "${tempdir}/source" 2 2 2621440  # 2 commits × 2 files × 2.5MB
echo "Source repo created." | indent

section_break
echo "Step 2: Initial push"
git init --bare -- "${tempdir}/encrypted.git" | indent
(
    cd "${tempdir}/source"
    git remote add cryptremote "gcrypt::${tempdir}/encrypted.git#${default_branch}"
    git push -f cryptremote "${default_branch}"
) 2>&1 | indent

echo "Objects after first push:"
list_object_sizes "${tempdir}/encrypted.git"
count1=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count: ${count1}"

section_break
echo "Step 3: Add more commits and push again"
(
    cd "${tempdir}/source"
    for ((i = 0; i < 2; i++)); do
        head -c 2621440 /dev/urandom > "extra_${i}.data"
    done
    git add .
    git commit -m "Extra commit"
    git push -f cryptremote "${default_branch}"
) 2>&1 | indent

echo "Objects after second push:"
list_object_sizes "${tempdir}/encrypted.git"
count2=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count: ${count2}"

# Should have more objects after second push
[[ ${count2} -gt ${count1} ]] || fail "Expected more objects after second push (${count2} <= ${count1})"
pass "Object count increased: ${count1} -> ${count2}"

section_break
echo "Step 4: Clone and verify all data"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted.git#${default_branch}" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
