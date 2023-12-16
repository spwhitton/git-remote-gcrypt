#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2023 Cathy J. Fitzpatrick <cathy@cathyjf.com>
# SPDX-License-Identifier: GPL-2.0-or-later
set -efuC -o pipefail
shopt -s inherit_errexit

# Unlike the main git-remote-gcrypt program, this testing script requires bash
# (rather than POSIX sh) and also depends on various common system utilities
# that the git-remote-gcrypt carefully avoids using (such as mktemp(1)).
#
# The test proceeds by setting up a new repository, making some large commits
# with random data into the repository, pushing the repository to another
# remote using git-remote-gcrypt over the gitception protocol, and then cloning
# the second repository and ensuring that the data it contains is correct.
#
# The random data is obtained from /dev/urandom. This script won't work
# on systems that don't provide /dev/urandom.
#
# The following settings specify the parameters to be used for the test.
num_commits=5
files_per_commit=3
random_source="/dev/urandom"
random_data_per_file=5242880 # 5 MiB
default_branch="main"
test_user_name="git-remote-gcrypt"
test_user_email="git-remote-gcrypt@example.com"
pack_size_limit="12m" # If this variable is unset, there is no size limit.

readonly num_commits files_per_commit random_source random_data_per_file \
    default_branch test_user_name test_user_email pack_size_limit

# Pipe text into this function to indent it with four spaces. This is used
# to make the output of this script prettier.
indent() {
    sed 's/^\(.*\)$/    \1/'
}

section_break() {
    echo
    printf '*%.0s' {1..70}
    echo $'\n'
}

assert() {
    (set +e; [[ -n ${show_command:-} ]] && set -x; "${@}")
    local -r status=${?}
    { [[ ${status} -eq 0 ]] && echo "Verification succeeded."; } || \
        echo "Verification failed."
    return "${status}"
}

fastfail() {
    "$@" || kill -- "-$$"
}

umask 077
tempdir=$(mktemp -d)
readonly tempdir
# shellcheck disable=SC2064
trap "rm -Rf -- '${tempdir}'" EXIT

# Set up the PATH to favor the version of git-remote-gcrypt from the repository
# rather than a version that might already be installed on the user's system.
PATH=$(git rev-parse --show-toplevel):${PATH}
readonly PATH
export PATH

# Unset any GIT_ environment variables to prevent them from affecting the test.
git_env=$(env | sed -n 's/^\(GIT_[^=]*\)=.*$/\1/p')
# shellcheck disable=SC2086
IFS=$'\n' unset ${git_env}

# Ensure a predictable gpg configuration.
export GNUPGHOME="${tempdir}/gpg"
mkdir "${GNUPGHOME}"
# Use a wrapper for gpg(1) to avoid cluttering the test output with unnecessary
# warnings about the obsolete `--secret-keyring` option. These warnings are
# caused by git-remote-gcrypt passing an option to gpg(1) that only makes sense
# for ancient versions of gpg(1), but addressing that (if it should be
# addressed at all) is a task best left for another day.
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

# Ensure a predictable git configuration.
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL="${tempdir}/gitconfig"
mkdir "${tempdir}/template" # Intentionally empty template directory.
git config --global init.defaultBranch "${default_branch}"
git config --global user.name "${test_user_name}"
git config --global user.email "${test_user_email}"
git config --global init.templateDir "${tempdir}/template"
git config --global gpg.program "${GNUPGHOME}/gpg"
[[ -n ${pack_size_limit:-} ]] && \
    git config --global pack.packSizeLimit "${pack_size_limit}"

# Prepare the random data that we'll be writing to the repository.
total_files=$(( num_commits * files_per_commit ))
random_data_size=$(( total_files * random_data_per_file ))
random_data_file="${tempdir}/data"
head -c "${random_data_size}" "${random_source}" > "${random_data_file}"

# Create gpg key and subkey.
echo "Step 1: Creating a new GPG key and subkey to use for testing:"
(
    set -x
    gpg --batch --passphrase "" --quick-generate-key \
        "${test_user_name} <${test_user_email}>"
    gpg -K
) 2>&1 | indent

###
section_break

echo "Step 2: Creating new repository with random data:"
{
    git init -- "${tempdir}/first"
    cd "${tempdir}/first"
    for ((i = 0; i < num_commits; ++i)); do
        for ((j = 0; j < files_per_commit; ++j)); do
            file_index=$(( i * files_per_commit + j ))
            random_data_index=$(( file_index * random_data_per_file ))
            # shellcheck disable=SC2016
            echo "Writing random file $((file_index + 1))/${total_files}:" \
                '${tempdir}'/"first/$(( file_index )).data "
            head -c "${random_data_per_file}" > "$(( file_index )).data" < \
                <(tail -c "+${random_data_index}" "${random_data_file}" || :)
            if command -v base64 > /dev/null; then
                # shellcheck disable=SC2312
                echo "First 24 bytes in base64:" \
                    "$(fastfail head -c 24 "$(( file_index )).data" | \
                        fastfail base64)" | indent
            fi
        done
        git add -- "${tempdir}/first"
        git commit -m "Commit #${i}"
    done

    echo
    echo "For reference, here is the commit log for the repository:"
    git log --format=oneline | indent
} | indent

###
section_break

echo "Step 3: Creating an empty bare repository to receive pushed data:"
git init --bare -- "${tempdir}/second.git" | indent


###
section_break

echo "Step 4: Pushing the first repository to the second one using gitception:"
{
    # Note that when pushing to a bare local repository, git-remote-gcrypt uses
    # gitception, rather than treating the remote as a local repository.
    (
        set -x
        cd "${tempdir}/first"
        git push -f "gcrypt::${tempdir}/second.git#${default_branch}" \
            "${default_branch}"
    ) 2>&1

    if command -v tree > /dev/null; then
        echo
        echo "For reference, here is the directory tree of second.git:"
        tree "${tempdir}/second.git"
    fi

    echo
    echo "Here is the size of each object file in second.git:"
    (
        cd "${tempdir}/second.git/objects"
        find . -type f -exec du -sh {} +
    ) | indent

    echo
    echo "Note that git-pack-objects(1) will try to ensure that each object is"
    echo "smaller than pack.packSizeLimit (${pack_size_limit:-unlimited}" \
        "here) but this isn't always"
    echo "possible because each object contains at least one of our random"
    echo "files, and each random file has a certain minimum size. As a result,"
    echo "pack.packSizeLimit is more of a suggestion than a hard limit."
 } | indent

###
section_break

echo "Step 5: Cloning the second repository using gitception:"
{
    (
        set -x
        git clone -b "${default_branch}" \
            "gcrypt::${tempdir}/second.git#${default_branch}" -- \
                "${tempdir}/third"
    ) 2>&1

    echo
    echo "Verifying that the first and third repositories have the same"
    echo "commit log as each other:"
    # shellcheck disable=SC2312
    assert diff \
        <(fastfail cd "${tempdir}/first"; fastfail git log --oneline) \
        <(fastfail cd "${tempdir}/third"; fastfail git log --oneline) \
            2>&1 | indent

    echo
    echo "Verifying that the first and third repositories have the same"
    echo "files in their respective working directories:"
    show_command=1 assert diff -r --exclude ".git" -- \
        "${tempdir}/first" "${tempdir}/third" 2>&1 | indent
} | indent
