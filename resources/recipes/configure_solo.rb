# First S3 manager, configured by chef-solo (rb_configure_initial_s3.sh) during the install:
# a single node cluster that listens on the sync address
extend Seaweedfs::Helpers

# Outside the resource block: its methods are looked up in the resource, not in this recipe
sync_ip = local_sync_ip

seaweedfs_config 'config' do
  ipaddress sync_ip
  action [:add]
end
