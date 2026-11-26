actions :add, :remove, :register, :deregister, :add_s3_conf_nginx, :add_malware
default_action :add

attribute :user, kind_of: String, default: 'seaweedfs'
attribute :group, kind_of: String, default: 'seaweedfs'
attribute :access_key_id, kind_of: String, default: 'redborder'
attribute :secret_key_id, kind_of: String, default: 'redborder'
# No default: the malware identity is only created with the credentials of its data bag
attribute :malware_access_key_id, kind_of: [String, NilClass], default: nil
attribute :malware_secret_key_id, kind_of: [String, NilClass], default: nil
attribute :s3_bucket, kind_of: String, default: 'bucket'
attribute :s3_malware_bucket, kind_of: String, default: 'malware'
attribute :s3_endpoint, kind_of: String, default: 's3.service'
attribute :s3_malware_endpoint, kind_of: String, default: 'malware.s3.service'
# Sync address of this node: every SeaweedFS service listens on it
attribute :ipaddress, kind_of: String, default: '127.0.0.1'
# Managers with the s3 service, in the same order in every node
attribute :managers_with_s3, kind_of: Array, default: []
# Cluster info of the managers ({ name => { 'ipaddress_sync' => ip } })
attribute :cluster_info, kind_of: Hash, default: {}
attribute :s3_hosts, kind_of: Array, default: ['localhost:8333']
