#!/bin/sh

set -e

: ${prefix:=/usr/local}
: ${DESTDIR:=}

verbose() { echo "$@" >&2 && "$@"; }
install_v()
{
	# Install $1 into $2/ with mode $3
	verbose install -d "$2" &&
	verbose install -m "$3" "$1" "$2"
}

install_v git-remote-gcrypt "$DESTDIR$prefix/bin" 755

if command -v rst2man >/dev/null
then
	rst2man='rst2man'
elif command -v rst2man.py >/dev/null # it is installed as rst2man.py on macOS
then
	rst2man='rst2man.py'
fi

if [ -n "$rst2man" ]
then
	trap 'rm -f git-remote-gcrypt.1.gz' EXIT
	verbose $rst2man ./README.rst | gzip -9 > git-remote-gcrypt.1.gz
	install_v git-remote-gcrypt.1.gz "$DESTDIR$prefix/share/man/man1" 644
else
	echo "'rst2man' not found, man page not installed" >&2
fi
