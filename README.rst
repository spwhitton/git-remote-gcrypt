=================
git-remote-gcrypt
=================

--------------------------------------
GNU Privacy Guard-encrypted git remote
--------------------------------------

:Manual section: 1

Description
===========

git-remote-gcrypt is a git remote helper to push and pull from
repositories encrypted with GnuPG, using a custom format.  This remote
helper handles URIs prefixed with `gcrypt::`.

Supported backends are `local`, `rsync://` and `sftp://`, where the
repository is stored as a set of files, or instead any `<giturl>`
where gcrypt will store the same representation in a git repository,
bridged over arbitrary git transport.  Prefer `local` or `rsync://` if
you can use one of those; see "Performance" below for discussion.

There is also an experimental `rclone://` backend for early adoptors
only (you have been warned).

The aim is to provide confidential, authenticated git storage and
collaboration using typical untrusted file hosts or services.

Installation
............

* use your GNU/Linux distribution's package manager -- Debian, Ubuntu,
  Fedora, Arch and some smaller distros are known to have packages

* run the supplied ``install.sh`` script on other systems

Quickstart
..........

Create an encrypted remote by pushing to it::

    git remote add cryptremote gcrypt::rsync://example.com/repo
    git push cryptremote master
    > gcrypt: Setting up new repository
    > gcrypt: Remote ID is :id:7VigUnLVYVtZx8oir34R
    > [ more lines .. ]
    > To gcrypt::[...]
    > * [new branch]      master -> master

Configuration
=============

The following ``git-config(1)`` variables are supported:

``remote.<name>.gcrypt-participants``
    ..
``gcrypt.participants``
    Space-separated list of GPG key identifiers. The remote is encrypted
    to these participants and only signatures from these are accepted.
    ``gpg -k`` lists all public keys you know.

    If this option is not set, we encrypt to your default key and accept
    any valid signature. This behavior can also be requested explicitly
    by setting participants to ``simple``.

    The ``gcrypt-participants`` setting on the remote takes precedence
    over the repository variable ``gcrypt.participants``.

``remote.<name>.gcrypt-publish-participants``
    ..
``gcrypt.publish-participants``
    By default, the gpg key ids of the participants are obscured by
    encrypting using ``gpg -R``. Setting this option to ``true`` disables
    that security measure.

    The problem with using ``gpg -R`` is that to decrypt, gpg tries each
    available secret key in turn until it finds a usable key.
    This can result in unnecessary passphrase prompts.

``gcrypt.gpg-args``
    The contents of this setting are passed as arguments to gpg.
    E.g. ``--use-agent``.

``remote.<name>.gcrypt-signingkey``
    ..
``user.signingkey``
    (The latter from regular git configuration) The key to use for signing.
    You should set ``user.signingkey`` if your default signing key is not
    part of the participant list. You may use the per-remote version
    to sign different remotes using different keys.

``remote.<name>.gcrypt-rsync-put-flags``
    ..
``gcrypt.rsync-put-flags``
    Flags to be passed to ``rsync`` when uploading to a remote using the
    ``rsync://`` backend. If the flags are set to a specific remote, the
    global flags, if also set, will not be applied for that remote.

``remote.<name>.gcrypt-require-explicit-force-push``
    ..
``gcrypt.require-explicit-force-push``
    A longstanding bug is that every git push effectively has a ``--force``.

    If this flag is set to ``true``, git-remote-gcrypt will refuse to push,
    unless ``--force`` is passed, or refspecs are prefixed with ``+``.

    There is a potential solution here: https://bugs.debian.org/877464#32

Environment variables
=====================

*GCRYPT_FULL_REPACK*
    When set (to anything other than the empty string), this environment
    variable forces a full repack when pushing.

Examples
========

How to set up a remote for two participants::

    git remote add cryptremote gcrypt::rsync://example.com/repo
    git config remote.cryptremote.gcrypt-participants "KEY1 KEY2"
    git push cryptremote master

How to use a git backend::

    # notice that the target git repo must already exist and its
    # `next` branch will be overwritten!
    git remote add gitcrypt gcrypt::git@example.com:repo#next
    git push gitcrypt master

The URL fragment (``#next`` here) indicates which backend branch is used.

Notes
=====

Collaboration
    The encryption of the manifest is updated for each push to match the
    participant configuration. Each pushing user must have the public
    keys of all collaborators and correct participant config.

Dependencies
    ``rsync``, ``curl`` and ``rclone`` for remotes ``rsync:``, ``sftp:`` and
    ``rclone:`` respectively. The main executable requires a POSIX-compliant
    shell that supports ``local``.

GNU Privacy Guard
    Both GPG 1.4 and 2 are supported. You need a personal GPG key. GPG
    configuration applies to algorithm choices for public-key
    encryption, symmetric encryption, and signing. See ``man gpg`` for
    more information.

Remote ID
    The Remote ID is not secret; it only ensures that two repositories
    signed by the same user can be distinguished.  You will see
    a warning if the Remote ID changes, which should only happen if the
    remote was re-created.

Performance
    Using an arbitrary `<giturl>` or an `sftp://` URI requires
    uploading the entire repository history with each push.  This
    means that pushes of your repository become slower over time, as
    your git history becomes longer, and it can easily get to the
    point that continued usage of git-remote-gcrypt is impractical.

    Thus, you should use these backends only when you know that your
    repository will not ever grow very large, not just that it's not
    large now.  This means that these backends are inappropriate for
    most repositories, and likely suitable only for unusual cases,
    such as small credential stores.  Even then, use `rsync://` if you
    can.  Note, however, that `rsync://` won't work with a repository
    hosting service like Gitolite, GitHub or GitLab.

rsync URIs
    The URI format for the rsync backend is ``rsync://user@host/path``,
    which translates to the rsync location ``user@host:/path``,
    accessed over ssh. Note that the path is absolute, not relative to the
    home directory. An earlier non-standard URI format is also supported:
    ``rsync://user@host:path``, which translates to the rsync location
    ``user@host:path``

rclone backend
    In addition to adding the rclone backend as a remote with URI like
    ``gcrypt::rclone://remote:subdir``, you must add the remote to the
    rclone configuration too.  This is typically done by executing
    ``rclone config``.  See rclone(1).

    The rclone backend is considered experimental and is for early
    adoptors only.  You have been warned.

Repository format
.................

| `EncSign(X):`   Sign and Encrypt to GPG key holder
| `Encrypt(K,X):` Encrypt using symmetric-key algorithm
| `Hash(X):`      SHA-2/256
|
| `B:` branch list
| `L:` list of the hash (`Hi`) and key (`Ki`) for each packfile
| `R:` Remote ID
|
| To write the repository:
|
| Store each packfile `P` as `Encrypt(Ki, P)` → `P'` in filename `Hi`
|   where `Ki` is a new random string and `Hash(P')` → `Hi`
| Store `EncSign(B || L || R)` in the manifest
|
| To read the repository:
|
| Get manifest, decrypt and verify using GPG keyring → `(B, L, R)`
| Warn if `R` does not match previously seen Remote ID
| for each `Hi, Ki` in `L`:
|   Get file `Hi` from the server → `P'`
|   Verify `Hash(P')` matches `Hi`
|   Decrypt `P'` using `Ki` → `P` then open `P` with git

Manifest file
.............

Example manifest file (with ellipsis for brevity)::

    $ gpg -d 91bd0c092128cf2e60e1a608c31e92caf1f9c1595f83f2890ef17c0e4881aa0a
    542051c7cd152644e4995bda63cc3ddffd635958 refs/heads/next
    3c9e76484c7596eff70b21cbe58408b2774bedad refs/heads/master
    pack :SHA256:f2ad50316...cd4ba67092dc4 z8YoAnFpMlW...3PkI2mND49P1qm
    pack :SHA256:a6e17bb4c...426492f379584 82+k2cbiUn7...dgXfyX6wXGpvVa
    keep :SHA256:f2ad50316...cd4ba67092dc4 1
    repo :id:OYiSleGirtLubEVqJpFF

Each item extends until newline, and matches one of the following:

``<sha-1> <gitref>``
    Git object id and its ref

``pack :<hashtype>:<hash> <key>``
    Packfile hash (`Hi`) and corresponding symmetric key (`Ki`).

``keep :<hashtype>:<hash> <generation>``
    Packfile hash and its repack generation

``repo <id>``
    The remote id

``extn <name> ...``
    Extension field, preserved but unused.

Detecting gcrypt repos
======================

To detect if a git url is a gcrypt repo, use: ``git-remote-gcrypt --check url``
Exit status is 0 if the repo exists and can be decrypted, 1 if the repo
uses gcrypt but could not be decrypted, and 100 if the repo is not
encrypted with gcrypt (or could not be accessed).

Note that this has to fetch the repo contents into the local git
repository, the same as is done when using a gcrypt repo.

Known issues
============

Every git push effectively has ``--force``.  Be sure to pull before
pushing.

git-remote-gcrypt can decide to repack the remote without warning,
which means that your push can suddenly take significantly longer than
you were expecting, as your whole history has to be reuploaded.
This push might fail over a poor link.

git-remote-gcrypt might report a repository as "not found" when the
repository does in fact exist, but git-remote-gcrypt is having
authentication, port, or network connectivity issues.

See also
========

git-remote-helpers(1), gpg(1)

Credits
=======

The original author of git-remote-gcrypt was GitHub user bluss.

The de facto maintainer in 2013 and 2014 was Joey Hess.

The current maintainer, since 2016, is Sean Whitton
<spwhitton@spwhitton.name>.

License
=======

This document and git-remote-gcrypt are licensed under identical terms,
GPL-3 (or 2+); see the git-remote-gcrypt file.

.. this document generates a man page with rst2man
.. vim: ft=rst tw=72 sts=4
