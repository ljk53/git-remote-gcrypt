#!/usr/bin/env bash
# Test: stale splitpack files from an interrupted push are cleaned up
# on the next push, not left to accumulate in $GIT_DIR/remote-gcrypt/.
TEST_NAME="Stale splitpack cleanup"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create repo"
create_test_repo "${tempdir}/source" 2 2 2621440
echo "Source repo created." | indent

section_break
echo "Step 2: Initial push to local backend"
mkdir -p "${tempdir}/encrypted-local"
(
    cd "${tempdir}/source"
    git remote add cryptlocal "gcrypt::${tempdir}/encrypted-local"
    git push -f cryptlocal "${default_branch}"
) 2>&1 | indent

section_break
echo "Step 3: Simulate stale splitpack files from a crashed push"
localdir="${tempdir}/source/.git/remote-gcrypt"
touch "${localdir}/splitpack-aaaa.pack" \
      "${localdir}/splitpack-aaaa.idx" \
      "${localdir}/splitpack-bbbb.pack"
stale_count=$(find "${localdir}" -name 'splitpack-*' | wc -l)
echo "Planted ${stale_count} stale files"
assert test "${stale_count}" -eq 3

section_break
echo "Step 4: Push again — stale files should be cleaned up"
(
    cd "${tempdir}/source"
    head -c 1048576 /dev/urandom > "extra.data"
    git add .
    git commit -m "Extra commit"
    git push -f cryptlocal "${default_branch}"
) 2>&1 | indent

remaining=$(find "${localdir}" -name 'splitpack-*' | wc -l)
echo "Splitpack files remaining after push: ${remaining}"
assert test "${remaining}" -eq 0

section_break
echo "Step 5: Clone and verify data integrity"
(
    git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted-local" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
