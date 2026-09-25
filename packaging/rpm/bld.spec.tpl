Name: bld
Version: @VERSION@
Release: 1%{?dist}
Summary: Build.io command-line client
License: Proprietary
URL: https://app.build.io
Packager: Build.io <support@build.io>
BuildArch: @ARCH@
Requires: ca-certificates
AutoReq: no
AutoProv: no

%description
Command-line client for Build.io, a Heroku-compatible PaaS.

%prep

%build

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{_sourcedir}/bld %{buildroot}/usr/bin/bld

%files
/usr/bin/bld
