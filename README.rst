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

.. NOTE:: This is a development version -- Repository format WILL change
          incompatibly soon again, secure protocol is done I think, but
          we will make it easier to use by doing away with the multiple
          repositories per URL and other things.

Quickstart
..........

* Install ``git-remote-gcrypt`` by running the supplied ``install.sh`` script.

* Create an encrypted remote by pushing to it:

    ::

        git remote add cryptremote gcrypt::rsync://example.com:repo
        git push cryptremote master
        > gcrypt: Setting up new repository
        > gcrypt: Repository ID is :id:7VigUnLVYVtZx8oir34R
        > [ more lines .. ]
        > To gcrypt::[...]
        > * [new branch]      master -> master

(The generated Repository ID is not secret, it only exists to ensure
that two repositories signed by the same user can be distinguished.
You will see a warning if the remote Repository ID changes, which will
only happen if the remote was re-created or switched out.)

Design Goals
............

Confidential, authenticated git storage and collaboration on any
untrusted file host or service. The only information we (by necessity)
leak is the approximate size and timing of updates.  PLEASE help me
evaluate how well we meet this design goal!

Configuration
=============

The following ``git-config(1)`` variables are supported:

``remote.<name>.gcrypt-participants``
        ..
``gcrypt.participants``
        Space-separated list of GPG key identifiers. The remote is
        encrypted to these participants and only signatures from these
        are accepted. ``gpg -k`` lists all public keys you know.

        When not set we encrypt to your default key and accept any valid
        signature. This behavior can also be requested explicitly by
        setting participants to ``simple``.

        The ``gcrypt-participants`` setting on the remote takes precedence
        over the repository variable ``gcrypt.participants``.

``user.signingkey``
        (From regular git configuration) The key to use for signing.
        You should set ``user.signingkey`` if your default signing key is
        not part of the participant list.

The encryption of the manifest is updated for each push. The pusher must
have the public keys of all collaborators.  You can commit a keyring to
the repo, further key management features do not yet exist.

GPG configuration applies to public-key encryption, symmetric
encryption, and signing. See `man gpg` for more information.

Environment Variables
=====================

*GCRYPT_FULL_REPACK*
        This environment variable forces full repack when pushing.

Examples
========

::

    git config gcrypt.participants YOURKEYID
    git remote add cryptremote  gcrypt::rsync://example.com:repo
    git push cryptremote HEAD

How to use a git backend::

    # notice that the target repo must already exist and its
    # `next` branch will be overwritten!
    git remote add gitcrypt gcrypt::git@example.com:repo#next
    git push gitcrypt HEAD

The URL fragment (`#next` here) indicates which branch is used.

Notes
=====

Repository Format
.................

::

    EncSign(X)   is sign+encrypt to a PGP key holder
    Encrypt(K,X) is symmetric encryption
    Hash(X)      is SHA-256

    B: branch list
    L: list of the hash (Hi) and key (Ki) for each packfile
    R: Repository ID
    
    Store Manifest as EncSign(B || L || R)
    Store each packfile P as P' = Encrypt(Ki, P) in filename Hi
        where Hi = Hash(P') and Ki is a random string

    To read the repository

    decrypt+verify Manifest using private key -> (B, L, R)
    warn if R does not match saved Repository ID for this remote
    for Hi, Ki in L:
        download file Hi from the server -> P'
        verify Hash(P') matches Hi
        decrypt P' using Ki -> P then open P with git

    Only packs mentioned in L are downloaded.

Manifest file
.............

::

    $ gpg -d 91bd0c092128cf2e60e1a608c31e92caf1f9c1595f83f2890ef17c0e4881aa0a
    542051c7cd152644e4995bda63cc3ddffd635958 refs/heads/next
    3c9e76484c7596eff70b21cbe58408b2774bedad refs/heads/master
    pack :SHA256:f2ad50316fbca42c553810aec3709c24974585ec1b34aae77d5cd4ba67092dc4 z8YoAnFpMlWPIYG8wo1adewd4Fp7Fo3PkI2mND49P1qm
    pack :SHA256:a6e17bb4c042bdfa8e38856ee6d058d0c0f0c575ace857c4795426492f379584 82+k2cbiUn7i2cW0dgXfyX6wXGpvVaQGj5sF59Y8my5W
    keep :SHA256:f2ad50316fbca42c553810aec3709c24974585ec1b34aae77d5cd4ba67092dc4 1
    repo :id:OYiSleGirtLubEVqJpFF

Each item extends until newline, and matches one of the following forms:

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


.. vim: ft=rst tw=72
.. this document generates a man page with rst2man

