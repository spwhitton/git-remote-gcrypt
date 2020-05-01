Submitting patches
==================

Thank you for your interest in contributing to this project!

Please **do not** submit a pull request on GitHub.  The repository
there is an automated mirror, and I don't develop using GitHub's
platform.

Project mailing lists
=====================

There are two low-volume project mailing lists, shared with some other
small free software projects:

- sgo-software-announce --
  <https://www.chiark.greenend.org.uk/mailman/listinfo/sgo-software-announce>

  For release announcements.

- sgo-software-discuss --
  <https://www.chiark.greenend.org.uk/mailman/listinfo/sgo-software-discuss>

  For bug reports, posting patches, user questions and discussion.

Please prepend ``[git-remote-gcrypt]`` to the subject line of your e-mail,
and for patches, pass ``--subject-prefix="PATCH git-remote-gcrypt"`` to
git-send-email(1).

Posting to sgo-software-discuss
-------------------------------

If you're not subscribed to the list, your posting will be held for
moderation; please be patient.

Whether or not you're subscribed, chiark.greenend.org.uk has
aggressive antispam.  If your messages aren't getting through, we can
easily add a bypass on chiark; please contact <spwhitton@spwhitton.name>.

If you don't want to deal with the mailing list and just want to send
patches, you should feel free to pass ``--to=spwhitton@spwhitton.name``
to git-send-email(1).

Alternatively, publish a git branch somewhere publically accessible (a
GitHub fork is fine) and write to me asking me to merge it.  I may
convert your branch back into patches when sending you feedback :)

Reporting bugs
==============

Please read "How to Report Bugs Effectively" to ensure your bug report
constitutes a useful contribution to the project:
<https://www.chiark.greenend.org.uk/~sgtatham/bugs.html>

Signing off your commits
========================

Contributions are accepted upstream under the terms set out in the
file ``COPYING``.  You must certify the contents of the file
``DEVELOPER-CERTIFICATE`` for your contribution.  To do this, append a
``Signed-off-by`` line to end of your commit message.  An easy way to
add this line is to pass the ``-s`` option to git-commit(1).  Here is
an example of a ``Signed-off-by`` line:

::

    Signed-off-by: Sean Whitton <spwhitton@spwhitton.name>
