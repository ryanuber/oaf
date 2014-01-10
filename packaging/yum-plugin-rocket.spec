%define _module_dir /usr/lib/ruby/1.8

name: oaf
summary: Care-free web app prototyping using files and scripts
version: 0.3.1
release: 1%{?dist}
buildarch: noarch
license: MIT
source0: %{name}.tar.gz
requires: ruby

%description
Oaf provides stupid-easy way of creating dynamic web applications by setting all
best practices and security considerations aside until you are sure that you
want to invest your time doing so.

Oaf was created as a weekend project to create a small, simple HTTP server
program that uses script execution as its primary mechanism for generating
responses.

%prep
%setup -n %{name}

%install
%{__mkdir_p} %{buildroot}/%{_module_dir}/%{name} %{buildroot}/usr/bin
%{__cp} -R lib/oaf.rb lib/oaf %{buildroot}/%{_module_dir}
%{__cp} bin/oaf %{buildroot}/usr/bin

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(0644,root,root,0755)
%dir %{_module_dir}/%{name}
%{_module_dir}/*
%defattr(0755,root,root,0755)
/usr/bin/%{name}

%changelog
* %(date "+%a %b %d %Y") %{name} - %{version}-%{release}
- Automatic build
