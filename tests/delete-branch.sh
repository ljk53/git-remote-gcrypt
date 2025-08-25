#!/bin/bash

set -e

echo "=== Git-remote-gcrypt Bug Reproduction Test ==="

# Setup test environment
TEST_ID="$$-$(date +%s)"
TEST_DIR="/tmp/gcrypt-test-$TEST_ID"
export GNUPGHOME="$TEST_DIR/.gnupg"
export GPG_TTY=$(tty)

echo "Setting up test environment in $TEST_DIR"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Step 1: Create temporary GPG environment
echo "Step 1: Creating temporary GPG key without passphrase..."
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

cat > "$GNUPGHOME/gpg.conf" << EOF
no-tty
batch
pinentry-mode loopback
EOF

cat > "$GNUPGHOME/gen-key-batch" << EOF
%echo Generating temporary test key
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: Test User
Name-Email: test@example.com
Expire-Date: 0
%no-protection
%no-ask-passphrase
%commit
%echo done
EOF

gpg --batch --generate-key "$GNUPGHOME/gen-key-batch" 2>/dev/null || {
    gpg --batch --gen-key "$GNUPGHOME/gen-key-batch" 2>/dev/null
}

KEY_FPR=$(gpg --list-secret-keys --with-colons | grep fpr | head -1 | cut -d: -f10)
echo "Created temporary key: $KEY_FPR"

# Step 2: Create local repository
echo "Step 2: Creating local repository..."
mkdir local-repo
cd local-repo
git init
git config user.name "Test User"
git config user.email "test@example.com"

DEFAULT_BRANCH=$(git symbolic-ref --short HEAD)
echo "Using branch: $DEFAULT_BRANCH"

# Step 3: Create initial commits
echo "Step 3: Creating initial commits..."
echo "Initial content" > file1.txt
git add file1.txt
git commit -m "Initial commit"

echo "Second file" > file2.txt
git add file2.txt
git commit -m "Second commit"

# Step 4: Create feature branch
echo "Step 4: Creating feature branch..."
git checkout -b feature-branch
echo "Feature content" > feature.txt
git add feature.txt
git commit -m "Feature commit"
git checkout $DEFAULT_BRANCH

# Step 5: Setup encrypted remote (using direct path, not file://)
echo "Step 5: Setting up encrypted remote..."
mkdir -p ../remote-repo
REMOTE_PATH="$(cd ../remote-repo && pwd)"

# Configure gcrypt
git config gcrypt.participants simple

# IMPORTANT: Use direct path, not file:// URL
# This avoids gitception mode
git remote add cryptremote "gcrypt::$REMOTE_PATH"

# Step 6: Initial push
echo "Step 6: Initial push to $DEFAULT_BRANCH..."
git push cryptremote $DEFAULT_BRANCH

# Step 7: Push feature branch
echo "Step 7: Push feature branch..."
git push cryptremote feature-branch

# Step 8: List branches
echo "Step 8: Current state..."
echo "Local branches:"
git branch | tee
echo ""
echo "Remote tracking:"
git ls-remote cryptremote | tee

# Step 9: Trigger the bug - delete remote branch
echo ""
echo "========================================="
echo "Step 9: ATTEMPTING TO DELETE REMOTE BRANCH"
echo "This should trigger the 'unary operator expected' bug"
echo "Command: git push cryptremote :feature-branch"
echo "========================================="
set +e

# Capture both stdout and stderr
git push cryptremote :feature-branch > ../output.log 2>&1
ERROR_CODE=$?

# Show the output
cat ../output.log

# Check for the bug
if grep -q "unary operator expected" ../output.log; then
    echo ""
    echo "========================================="
    echo "✓✓✓ BUG SUCCESSFULLY REPRODUCED! ✓✓✓"
    echo "========================================="
    echo "Found the error at:"
    grep -n "unary operator expected" ../output.log
    echo ""
    echo "The bug occurs when src_ is empty"
else
    echo ""
    echo "========================================="
    if [ $ERROR_CODE -eq 0 ]; then
        echo "× Bug NOT reproduced - deletion succeeded"
        echo "Your version might already be fixed"
    else
        echo "× Command failed with different error (code: $ERROR_CODE)"
    fi
    echo "========================================="
fi
