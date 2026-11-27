Name: cookbook-seaweedfs
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: SeaweedFS cookbook to install and configure it in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-seaweedfs
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/seaweedfs
cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/seaweedfs
chmod -R 0755 %{buildroot}/var/chef/cookbooks/seaweedfs
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/seaweedfs/README.md

%pre
if [ -d /var/chef/cookbooks/seaweedfs ]; then
    rm -rf /var/chef/cookbooks/seaweedfs
fi

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    if systemctl is-active --quiet opscode-erchef; then
      su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload seaweedfs'
    fi
  ;;
esac

%postun
# Deletes directory when uninstall the package
if [ "$1" = 0 ] && [ -d /var/chef/cookbooks/seaweedfs ]; then
  rm -rf /var/chef/cookbooks/seaweedfs
fi

%files
%defattr(0644,root,root)
%attr(0755,root,root)
/var/chef/cookbooks/seaweedfs
%defattr(0644,root,root)
/var/chef/cookbooks/seaweedfs/README.md

%doc

%changelog
* Thu Nov 26 2026 Miguel Negrón <manegron@redborder.com>
- First version: SeaweedFS cluster (master, volume, filer + S3) replacing cookbook-minio
