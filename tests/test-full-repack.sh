#!/usr/bin/env bash
# Test: GCRYPT_FULL_REPACK with split packs.
# Push incrementally, then push with GCRYPT_FULL_REPACK and verify
# that the repack consolidates correctly and data survives.
TEST_NAME="GCRYPT_FULL_REPACK with split packs"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create initial repo"
create_test_repo "${tempdir}/source" 2 2 2621440
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

section_break
echo "Step 3: Add more commits"
(
    cd "${tempdir}/source"
    head -c 2621440 /dev/urandom > "extra.data"
    git add .
    git commit -m "Extra commit"
    git push -f cryptremote "${default_branch}"
) 2>&1 | indent

echo "Objects after incremental push:"
list_object_sizes "${tempdir}/encrypted.git"
count_before=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count before repack: ${count_before}"

section_break
echo "Step 4: Push with GCRYPT_FULL_REPACK"
(
    cd "${tempdir}/source"
    # Add a trivial change to trigger a push
    echo "trigger repack" > trigger.txt
    git add .
    git commit -m "Trigger repack"
    GCRYPT_FULL_REPACK=1 git push -f cryptremote "${default_branch}"
) 2>&1 | indent

echo "Objects after full repack:"
list_object_sizes "${tempdir}/encrypted.git"
count_after=$(count_pack_objects "${tempdir}/encrypted.git")
echo "Object count after repack: ${count_after}"

section_break
echo "Step 5: Clone and verify"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted.git#${default_branch}" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
