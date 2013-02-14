
:Command:       git-remote-gcrypt

:Copyright:     2013  by Ulrik Sverdrup
:License:       GPLv2 or any later version, see http://www.gnu.org/licenses/
:Decscription:  Use GnuPG to use encrypted git remotes

.. NOTE:: Repository format MAY STILL change, incompatibly

Introduction
------------

Install as `git-remote-gcrypt` in `$PATH`

Supports local, ssh:// and sftp:// remotes at the moment, as well as
the special gitception://<giturl> remote type, using any existing git
repository as backend.

Example use::

    gpg --export KEY1 KEY2 > $PWD/.git/keyring.gpg
    git config --path gcrypt.keyring $PWD/.git/keyring.gpg
    git remote add cryptremote  gcrypt::ssh://example.com:repo
    git push cryptremote master
    > gcrypt: Setting up new repository at ssh://example.com:repo
    > gcrypt: Repository ID  is KNBr0wKzct52
    > gcrypt: Repository URL is gcrypt::ssh://example.com:repo/G.KNBr0wKzct52
    > gcrypt: (configuration for cryptremote updated)
    > [ more lines .. ]
    > To gcrypt::[...]
    > * [new branch]      master -> master

The generated Repository ID is not secret, it only exists to ensure that
two repositories signed by the same user can not be (maliciously) switched
around. It incidentally allows multiple repositories to all share location.

Share the updated Repository URL with everyone in the keyring.

Design Goals
------------

+ Confidential, authenticated git storage and collaboration on any
  untrusted file host or service. The only information we (by necessity)
  leak is the approximate size and timing of updates.
  PLEASE help me evaluate how well we meet this design goal!

Configuration
-------------

+ You must set up a small gpg keyring for the repository::

    gpg --export KEYID1 > <path-to-keyring>
    git config gcrypt.keyring <path-to-keyring>

  .. NOTE:: GnuPG's configuration applies. Check your key and general
            preferences, see `man gpg`.

+ All readers of the repository must have their pubkey included in
  the keyring used when pushing. All writers must have the complete
  set of pubkeys available. You can commit the keyring to the repo,
  further key management features do not yet exist.

+ gcrypt obeys `user.signingkey`


Repository Format
-----------------

+ Protocol sketch::

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

+ The manifest looks like this::

    $ gpg -d < 5a191cea8c1021a95d813c4007c14f2cc987a40880c2f669430f1916
    b4a4a39365d19282810c19d0f3f24d04dd2d179f refs/tags/version1
    1d323ddadf4cf1d80fced447e637ab3766b168b7 refs/heads/master
    pack :SHA224:cfdf36515e0d0820554fe5fd9f00a4bee17bcf88ec8a752d851c46ee Rc+j8\
    Nv6GOW3mBhWOx6W6jjz3BTX7B6XIJ6RYI+P4TEyy+X6p2PB/fsBL9la0Tuc
    pack :SHA224:a43ccd208d3bd2ea582dbd5407cb8ed6e18b150b1da25c806115eaa5 UXR3/\
    R7awFCUJWYdzXzrlkk7E2Acxq/Y4EfEcd62AwGGe0o0QxL+s5CwWI/NvMhb
    repo :SHA224:5a191cea8c1021a95d813c4007c14f2cc987a40880c2f669430f1916 1

+ Manifest fields:

  + `<fieldname><space><value>`, extends until newline.
  + `{0-9a-f}[40]`, `pack`, `repo`, `keep` (planned), `extn` (extension
    fields, preserved but unused).


Pieces yet to be Implemented
----------------------------

+ Repacking the remote repository
+ Deleting remote refs
+ Some kind of simple keyring management

.. vim: ft=rst tw=74
