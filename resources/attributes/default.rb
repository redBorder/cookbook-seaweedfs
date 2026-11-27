default['seaweedfs']['user'] = 'seaweedfs'
default['seaweedfs']['group'] = 'seaweedfs'

# HTTP ports. The gRPC port of each one is the HTTP port + 10000 (weed default).
# volume and filer do not use the weed defaults (8080 and 8888): they are taken in the managers
default['seaweedfs']['master_port'] = 9333
default['seaweedfs']['volume_port'] = 9340
default['seaweedfs']['filer_port'] = 9350
default['seaweedfs']['s3_port'] = 8333

# Masters (Raft): 1 with 1 or 2 S3 managers, 3 with 3 or more
default['seaweedfs']['max_masters'] = 3
# Size of each volume: small volumes spread better between managers with small disks
default['seaweedfs']['volume_size_limit_mb'] = 1024
# Low free space marks the volumes read only
default['seaweedfs']['min_free_space'] = '5'

default['seaweedfs']['access_key_id'] = 'redborder'
default['seaweedfs']['secret_key_id'] = 'redborder'
default['seaweedfs']['s3_bucket'] = 'bucket'
default['seaweedfs']['s3_malware_bucket'] = 'malware'
default['seaweedfs']['s3_endpoint'] = 's3.service'
default['seaweedfs']['s3_malware_endpoint'] = 'malware.s3.service'

# Flags
default['seaweedfs']['registered'] = false
default['seaweedfs']['replication'] = nil
