%global debug_package %{nil}

Name:		git-remote-gcrypt
Version:	1.0.2
Release:	1%{?dist}
Summary:	GNU Privacy Guard-encrypted git remote

Group:		Development Tools
License:	GPLv3
URL:		https://git.spwhitton.name/%{name}
Source0:	%{name}-%{version}.tar.gz

BuildRequires:	python2-docutils
Requires:	gnupg2 git-core

%description
Remote helper programs are invoked by git to handle network transport.
This helper handles gcrypt:: URLs that will access a remote repository
encrypted with GPG, using our custom format.

Supported locations are local, rsync:// and sftp://, where the
repository is stored as a set of files, or instead any <giturl> where
gcrypt will store the same representation in a git repository, bridged
over arbitrary git transport.

The aim is to provide confidential, authenticated git storage and
collaboration using typical untrusted file hosts or services.

%prep
%setup -q -n %{name}

%build
:

%install
export DESTDIR="%{buildroot}"
export prefix="%{_prefix}"
./install.sh

%files
/usr/bin/%{name}
%doc /usr/share/man/man1/%{name}.1.gz

%changelog

