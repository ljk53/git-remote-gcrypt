#!/usr/bin/env bash
# Shared test helpers for git-remote-gcrypt split-pack tests.
# Source this file from individual test scripts.

set -efuC -o pipefail
shopt -s inherit_errexit

TEST_NAME="${TEST_NAME:-unnamed-test}"

indent() { sed 's/^\(.*\)$/    \1/'; }

section_break() {
    echo
    printf '*%.0s' {1..70}
    echo $'\n'
}

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

assert() {
    (set +e; [[ -n ${show_command:-} ]] && set -x; "${@}")
    local -r status=${?}
    [[ ${status} -eq 0 ]] && pass "${FUNCNAME[1]:-assert}: ${*}" || fail "${FUNCNAME[1]:-assert}: ${*}"
    return "${status}"
}

fastfail() { "$@" || kill -- "-$$"; }

# Create isolated temp dir with cleanup trap
umask 077
tempdir=$(mktemp -d)
readonly tempdir
# shellcheck disable=SC2064
trap "rm -Rf -- '${tempdir}'" EXIT

echo "=== ${TEST_NAME} ==="
echo "Temp dir: ${tempdir}"

# Use repo's git-remote-gcrypt, not system one
PATH=$(git rev-parse --show-toplevel):${PATH}
readonly PATH
export PATH

# Isolate GIT_ env vars
git_env=$(env | sed -n 's/^\(GIT_[^=]*\)=.*$/\1/p')
# shellcheck disable=SC2086
IFS=$'\n' unset ${git_env}

# Setup isolated GPG
export GNUPGHOME="${tempdir}/gpg"
mkdir "${GNUPGHOME}"
cat << 'EOF' > "${GNUPGHOME}/gpg"
#!/usr/bin/env bash
set -efuC -o pipefail; shopt -s inherit_errexit
args=( "${@}" )
for ((i = 0; i < ${#}; ++i)); do
    if [[ ${args[${i}]} = "--secret-keyring" ]]; then
        unset "args[${i}]" "args[$(( i + 1 ))]"
        break
    fi
done
exec gpg "${args[@]}"
EOF
chmod +x "${GNUPGHOME}/gpg"

gpg --batch --passphrase "" --quick-generate-key \
    "test-gcrypt <test@example.com>" 2>/dev/null

# Setup isolated git config
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL="${tempdir}/gitconfig"
default_branch="main"
mkdir "${tempdir}/template"
git config --global init.defaultBranch "${default_branch}"
git config --global user.name "test-gcrypt"
git config --global user.email "test@example.com"
git config --global init.templateDir "${tempdir}/template"
git config --global gpg.program "${GNUPGHOME}/gpg"

# Helper: create a repo with random data commits
# $1 = repo path, $2 = num_commits, $3 = files_per_commit, $4 = bytes_per_file
create_test_repo() {
    local repo_path="$1" n_commits="$2" n_files="$3" file_size="$4"
    git init -- "${repo_path}"
    (
        cd "${repo_path}"
        for ((i = 0; i < n_commits; i++)); do
            for ((j = 0; j < n_files; j++)); do
                head -c "${file_size}" /dev/urandom > "file_${i}_${j}.data"
            done
            git add .
            git commit -m "Commit #${i}"
        done
    )
}

# Helper: verify two repos have identical content
# $1 = repo_a path, $2 = repo_b path
verify_repos_match() {
    local repo_a="$1" repo_b="$2"
    echo "Verifying commit logs match:"
    # shellcheck disable=SC2312
    assert diff \
        <(fastfail cd "${repo_a}"; fastfail git log --oneline) \
        <(fastfail cd "${repo_b}"; fastfail git log --oneline)

    echo "Verifying file contents match:"
    show_command=1 assert diff -r --exclude ".git" -- "${repo_a}" "${repo_b}"
}

# Helper: count encrypted object files in a remote
# $1 = remote path (bare git repo or local dir)
count_pack_objects() {
    local remote_path="$1"
    if [[ -d "${remote_path}/objects" ]]; then
        # Gitception: objects are in git object store
        find "${remote_path}/objects" -type f ! -name "*.idx" ! -name "*.pack" \
            ! -name "*.rev" ! -path "*/info/*" | wc -l
    else
        # Local path: files directly in directory
        find "${remote_path}" -type f | wc -l
    fi
}

# Helper: list sizes of encrypted objects
# $1 = remote path
list_object_sizes() {
    local remote_path="$1"
    if [[ -d "${remote_path}/objects" ]]; then
        (cd "${remote_path}/objects" && find . -type f -exec du -sh {} + 2>/dev/null) | indent
    else
        (cd "${remote_path}" && find . -type f -exec du -sh {} + 2>/dev/null) | indent
    fi
}
