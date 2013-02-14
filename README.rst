
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
    > gcrypt: Repository ID is 99b45a84a13168fc5efe
    > gcrypt: Repository URL is gcrypt::ssh://example.com:repo/G/99b45a84a13168fc5efe
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

  .. NOTE:: We use the user's gnupg configuration for `cipher-algo` and so on!
            Check your keys and key preferences, see `man gpg`.

+ All readers of the repository must have their pubkey included in
  the keyring used when pushing. All writers must have the complete
  set of pubkeys available. You can commit the keyring to the repo,
  further key management features do not yet exist.


Repository Format
-----------------

+ Protocol sketch::

    EncSign(X)   is sign+encrypt to a PGP key holder
    Encrypt(K,X) is symmetric encryption
    Hash(X)      is SHA-224

    K: master key, generated once, 128 bytes
    B: branch list
    L: list of packfile hashes
    R: Hash(Repository ID)
    
    Store Manifest as EncSign(K || B || L || R) in filename R
    Each packfile P is stored as P' = Encrypt(K,P) in filename Hash(P')
    L is the list of Hash(P').

    To read the repository

    decrypt+verify Manifest using private key -> (K, B, L, R)
    verify R matches Hash(Requested Repository ID)
    for each entry in L:
        get the entry from the server -> P'
        verify  Hash(P') matches the entry in L
        decrypt P' using K -> P -> open P with git

    Only packs mentioned in L are downloaded.

+ The manifest looks like this::

     $ gpg -d < 9f42017de5cb482e509ff147d54ceeb0413d6379717f3f0db770f00a
     T+pCUr/1FxbBC93ABIiIgG36EgqaxvgdNYjdmRSueGkgGETc4Qs7di+/yIsq2R5GysiqFaR0 \
     bGSWf9omsoAH84hmED/kR/ZQiOGT/vg2Pg7CGI0xzdlW9GQjeFBAo4vsDDDBxrn5L7F9E532 \
     LOnnPLSIZD7BpmyY/oZiXoP5Vlw=
     b4a4a39365d19282810c19d0f3f24d04dd2d179f refs/tags/something
     1d323ddadf4cf1d80fced447e637ab3766b168b7 refs/heads/master
     pack :SHA224:00ef27cc2c5b76365e1a46479ed7429e16572c543cdff0a8bf745c7c
     pack :SHA224:b934d8d6c0f48e71b9d7a4d5ea56f024a9bed4f6f2c6f8e688695bee
     repo 9f42017de5cb482e509ff147d54ceeb0413d6379717f3f0db770f00a


.. vim: ft=rst tw=74
