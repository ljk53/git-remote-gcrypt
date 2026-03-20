#!/usr/bin/env bash
# Test: cross-device push — git-remote-gcrypt Tempdir on a different
# filesystem than the git repo.  Reproduces the "Invalid cross-device link"
# error when git pack-objects creates temp files in .git/objects/pack/
# and tries to rename them to the Tempdir on another filesystem.
TEST_NAME="Cross-device split pack push"
# shellcheck source=test-helpers.sh
source "$(dirname "$0")/test-helpers.sh"

# We need a filesystem different from where the repo lives.
# /dev/shm is almost always tmpfs on Linux.
if [[ ! -d /dev/shm ]]; then
    echo "SKIP: /dev/shm not available for cross-device test"
    exit 0
fi

# Check that /dev/shm is actually a different device
repo_dev=$(stat -c '%d' "${tempdir}")
shm_dev=$(stat -c '%d' /dev/shm)
if [[ "${repo_dev}" == "${shm_dev}" ]]; then
    echo "SKIP: /dev/shm is on the same filesystem as tempdir"
    exit 0
fi

echo "repo filesystem device: ${repo_dev}"
echo "  shm filesystem device: ${shm_dev}"

git config --global pack.packSizeLimit 5m

section_break
echo "Step 1: Create repo (~10MB to trigger split packs)"
create_test_repo "${tempdir}/source" 2 2 2621440
echo "Source repo created." | indent

section_break
echo "Step 2: Push with TMPDIR on a different filesystem (/dev/shm)"
mkdir -p "${tempdir}/encrypted-local"
(
    cd "${tempdir}/source"
    git remote add cryptlocal "gcrypt::${tempdir}/encrypted-local"
    # Force gcrypt to use /dev/shm for its Tempdir — different filesystem
    TMPDIR=/dev/shm git push -f cryptlocal "${default_branch}"
) 2>&1 | indent

section_break
echo "Step 3: Verify encrypted remote has multiple pack files"
file_count=$(find "${tempdir}/encrypted-local" -type f | wc -l)
echo "Encrypted file count: ${file_count}"
# Manifest + at least 2 packs (10MB with 5m limit)
assert test "${file_count}" -ge 3

section_break
echo "Step 4: Clone and verify"
(
    TMPDIR=/dev/shm git clone -b "${default_branch}" \
        "gcrypt::${tempdir}/encrypted-local" -- \
        "${tempdir}/cloned"
) 2>&1 | indent

verify_repos_match "${tempdir}/source" "${tempdir}/cloned"

section_break
echo "=== PASSED: ${TEST_NAME} ==="
