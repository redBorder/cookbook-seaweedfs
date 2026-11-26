extend Seaweedfs::Helpers

# Outside the resource block: its methods are looked up in the resource, not in this recipe
sync_ip = local_sync_ip

seaweedfs_config 'config' do
  ipaddress sync_ip
  action :add
end
