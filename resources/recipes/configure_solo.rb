# First S3 manager, configured by chef-solo (rb_configure_initial_s3.sh) during the install:
# a single node cluster that listens on the sync address
extend Seaweedfs::Helpers

seaweedfs_config 'config' do
  ipaddress local_sync_ip
  action [:add]
end
