=================
git-remote-gcrypt
=================

--------------------------------------
GNU Privacy Guard-encrypted git remote
--------------------------------------

:Author: Ulrik Sverdrup
:Manual section: 1

Description
===========

Remote helper programs are invoked by git to handle network transport.
This helper handles `gcrypt::` URLs that will access a remote repository
encrypted with GPG, using our custom format.

Supported locations are `local`, `rsync://` and `sftp://`, where
the repository is stored as a set of files, or instead any `<giturl>`
where gcrypt will store the same representation in a git repository,
bridged over arbitrary git transport.

The aim is to provide confidential, authenticated git storage and
collaboration using typical untrusted file hosts or services.
PLEASE help us evaluate how well we meet this design goal!

.. NOTE:: This is a development version -- Repository format MAY CHANGE.

Quickstart
..........

* Install ``git-remote-gcrypt`` by running the supplied ``install.sh`` script.

* Create an encrypted remote by pushing to it::

    git remote add cryptremote gcrypt::rsync://example.com:repo
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

    When not set we encrypt to your default key and accept any valid
    signature. This behavior can also be requested explicitly by setting
    participants to ``simple``.

    The ``gcrypt-participants`` setting on the remote takes precedence
    over the repository variable ``gcrypt.participants``.

``user.signingkey``
    (From regular git configuration) The key to use for signing.  You
    should set ``user.signingkey`` if your default signing key is not
    part of the participant list.

Environment Variables
=====================

*GCRYPT_FULL_REPACK*
    This environment variable forces full repack when pushing.

Examples
========

How to set up a remote for two participants::

    git remote add cryptremote gcrypt::rsync://example.com:repo
    git config remote.cryptremote.gcrypt-participants "KEY1 KEY2"
    git push cryptremote master

How to use a git backend::

    # notice that the target git repo must already exist and its
    # `next` branch will be overwritten!
    git remote add gitcrypt gcrypt::git@example.com:repo#next
    git push gitcrypt master

The URL fragment (`#next` here) indicates which backend branch is used.

Notes
=====

Collaboration
    The encryption of the manifest is updated for each push to match the
    participant configuration. Each pushing user must have the public
    keys of all collaborators and correct participant config. You can
    commit a keyring to the repo; further key management features do not
    yet exist.

Dependencies
    ``rsync`` and ``curl`` for remotes ``rsync:`` and ``sftp:``
    respectively. The main executable requires a POSIX-compliant shell
    that supports ``local``.

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

Repository Format
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
    The repository id

``extn <name> ...``
    Extension field, preserved but unused.

See Also
========

git-remote-helpers(1), gpg(1)

License
=======

git-remote-gcrypt is licensed under the terms of the GNU GPL version 2
(or at your option, any later version). See http://www.gnu.org/licenses/

.. this document generates a man page with rst2man
.. vim: ft=rst tw=72 sts=4
