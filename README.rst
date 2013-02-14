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
This helper handles gcrypt:: URLs that will access a remote repository
encrypted with GPG, using our custom format.

Supported locations are `local`, `ssh://`, `rsync://` and `sftp`, where
the repository is stored as a set of files, or instead any `<giturl>`
where gcrypt will store the same representation in a git repository,
bridged over arbitrary git transport.

.. NOTE:: Repository format MAY STILL change, incompatibly. We may
          not continue to support all types of remote transport.

Quickstart
..........

* Install `git-remote-gcrypt` by running the supplied `install.sh` script.

* Configure the list of participant gpg keys:

    ::

        git config --global gcrypt.participants YOURKEYID

* Create an encrypted remote by pushing to it:

    ::

        git remote add cryptremote gcrypt::ssh://example.com:repo
        git push cryptremote master
        > gcrypt: Setting up new repository at ssh://example.com:repo
        > gcrypt: Repository ID  is KNBr0wKzct52
        > gcrypt: Repository URL is gcrypt::ssh://example.com:repo#KNBr0wKzct52
        > gcrypt: (configuration for cryptremote updated)
        > [ more lines .. ]
        > To gcrypt::[...]
        > * [new branch]      master -> master

* Share the updated Repository URL with all participants.

(The generated Repository ID is not secret, it only exists to ensure
that two repositories signed by the same user can not be maliciously
switched around. It incidentally allows multiple repositories to all
share location.)

Design Goals
............

Confidential, authenticated git storage and collaboration on any
untrusted file host or service. The only information we (by necessity)
leak is the approximate size and timing of updates.  PLEASE help me
evaluate how well we meet this design goal!

Configuration
=============

*gcrypt.participants*
        Space-separated list of GPG key identifiers. The remote is
        encrypted to these participants and only signatures from these
        are accepted. ``gpg -k`` lists all public keys you know.

You should set *user.signingkey* if your default signing key is not part
of the participant list.

The encryption of the manifest is updated for each push. The pusher must
have the public keys of all collaborators.  You can commit a keyring to
the repo, further key management features do not yet exist.

GPG configuration applies to public-key encryption, symmetric
encryption, and signing. See `man gpg` for more information.


Examples
========

::

    git config gcrypt.participants YOURKEYID
    git remote add cryptremote  gcrypt::ssh://example.com:repo
    git push cryptremote HEAD

How to use a git backend::

    # notice that the target repo must already exist and its
    # `master` branch will be overwritten!
    git remote add gitcrypt gcrypt::git@example.com:repo
    git push gitcrypt HEAD

Notes
=====

Repository Format
.................

::

    EncSign(X)   is sign+encrypt to a PGP key holder
    Encrypt(K,X) is symmetric encryption
    Hash(X)      is SHA-224

    B: branch list
    L: list of the hash (Hi) and key (Ki) for each packfile
    R: Hash(Repository ID)
    
    Store Manifest as EncSign(B || L || R) in filename R
    Store each packfile P as P' = Encrypt(Ki, P) in filename Hi
        where Hi = Hash(P') and Ki is a random string

    To read the repository

    decrypt+verify Manifest using private key -> (B, L, R)
    verify R matches Hash(Requested Repository ID)
    for Hi, Ki in L:
        download file Hi from the server -> P'
        verify Hash(P') matches Hi
        decrypt P' using Ki -> P then open P with git

    Only packs mentioned in L are downloaded.

Manifest file
.............

::

    $ gpg -d < 5a191cea8c1021a95d813c4007c14f2cc987a40880c2f669430f1916
    b4a4a39365d19282810c19d0f3f24d04dd2d179f refs/tags/version1
    1d323ddadf4cf1d80fced447e637ab3766b168b7 refs/heads/master
    pack :SHA224:cfdf36515e0d0820554fe5fd9f00a4bee17bcf88ec8a752d851c46ee \
    Rc+j8Nv6GOW3mBhWOx6W6jjz3BTX7B6XIJ6RYI+P4TEy
    pack :SHA224:a43ccd208d3bd2ea582dbd5407cb8ed6e18b150b1da25c806115eaa5 \
    UXR3/R7awFCUJWYdzXzrlkk7E2Acxq/Y4EfEcd62AwGG
    repo :SHA224:5a191cea8c1021a95d813c4007c14f2cc987a40880c2f669430f1916 1

+ `field<space>value`, extends until newline.

+ `field` is one of `[0-9a-f]{40}`, `pack`, `repo`, `keep`, `extn`.

  `[0-9a-f]{40} <gitref>`
      SHA-1 and its git ref

  `pack :<hashtype>:<hash> <key>`
      Packfile hash (`Hi`) and corresponding symmetric key (`Ki`).

  `repo :<hashtype>:<hash> <version>`
      The hash of the repository id.

  `extn ...`
      Extension field, preserved but unused.

  `keep ...`
      TBD.


Yet to be Implemented
.....................

+ Repacking the remote repository
+ Some kind of simple keyring management

See Also
========

git-remote-helpers(1), gpg(1)

License
=======

git-remote-gcrypt is licensed under the terms of the GNU GPL version 2
(or at your option, any later version). See http://www.gnu.org/licenses/


.. vim: ft=rst tw=72
.. this document generates a man page with rst2man

