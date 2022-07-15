=================
Git pre-receive Hook for git-remote-gcrypt
=================

Description
===========

The new versoin of git-remote-gcrypt writes the commit history into the commit message, because previously every push was a force push and 
the commit message was just "Initial Commit" which is not helpfull. To prevent this history from being tampered, we check it server-sided. 

This is the server side part (git pre-receive hook).

This hook checks that the commit message contains the key IDs of the keys that have currently access to the manifest file and the unaltered commit history.

Installation
............

* enable hooks for your repository

* put this code into the respective location of your git server


How does it work?
=================

The script does these steps:

* 1 get the pending manifestfile 

* 2 the content of the commit message is extracted from the pushed commit

* 3 get the previous commit message from the git log

* 4 compare the commit messages from steps 2 & 3 and that the newly added line (author, hash, keys, ...) is equal to the previous commit

* 5 use gpg to determine which keys are able to decrypt the manifest

* 6 compare the keys found in step 5 with the keys mentioned in the commit message found in step 2



Miscellaneous
.............

    Format of the history in every commit message:

    <KEY1> <KEY2> <KEY3>
    2000-01-01 08:00:00 +0600 AuthorName CommitID <KEY1> <KEY2> 
    2000-01-01 07:00:00 +0600 AuthorName CommitID <KEY0>
    2000-01-01 06:00:00 +0600 AuthorName CommitID <KEY0>
