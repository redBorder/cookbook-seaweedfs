# Cookbook:: seaweedfs
# Provider:: config

include Seaweedfs::Helpers

action :add do
  begin
    group = new_resource.group
    ipaddress = new_resource.ipaddress
    s3_bucket = new_resource.s3_bucket
    s3_malware_bucket = new_resource.s3_malware_bucket
    s3_endpoint = new_resource.s3_endpoint
    s3_malware_endpoint = new_resource.s3_malware_endpoint
    cdomain = get_cdomain

    s3_nodes = s3_cluster_nodes(new_resource.managers_with_s3, new_resource.cluster_info, ipaddress)
    masters = seaweedfs_masters(s3_nodes)
    replication = seaweedfs_replication(s3_nodes)
    is_master = masters.include?(ipaddress)

    # The first S3 manager creates the credentials, the rest get them from the data bag
    if !s3_ready?
      s3_user = generate_random_key(20)
      s3_password = generate_random_key(40)
      s3_malware_user = generate_random_key(20)
      s3_malware_password = generate_random_key(40)
    else
      s3_user = new_resource.access_key_id
      s3_password = new_resource.secret_key_id
      s3_malware_user = new_resource.malware_access_key_id
      s3_malware_password = new_resource.malware_secret_key_id
    end

    dnf_package 'redborder-seaweedfs' do
      action :upgrade
    end

    # Declared before the templates that notify them. On the first run they do not start
    # (ConditionPathExists of the units) until the delayed restart after the templates
    services = %w(seaweedfs-volume seaweedfs-filer)
    services.unshift('seaweedfs-master') if is_master
    services.each do |svc|
      service svc do
        service_name svc
        ignore_failure true
        supports status: true, restart: true, enable: true
        action [:enable, :start]
      end
    end

    # S3 identities: the admin user and the malware user, limited to its bucket
    identities = [
      {
        'name' => 'redborder',
        'credentials' => [{ 'accessKey' => s3_user, 'secretKey' => s3_password }],
        'actions' => %w(Admin Read Write List Tagging),
      },
    ]
    if s3_malware_user && s3_malware_password
      identities << {
        'name' => 'malware',
        'credentials' => [{ 'accessKey' => s3_malware_user, 'secretKey' => s3_malware_password }],
        'actions' => %w(Read Write List Tagging).map { |a| "#{a}:#{s3_malware_bucket}" },
      }
    end

    template '/etc/seaweedfs/s3.json' do
      source 's3.json.erb'
      cookbook 'seaweedfs'
      owner 'root'
      group group
      mode '0640'
      sensitive true
      variables(config: { 'identities' => identities })
      notifies :restart, 'service[seaweedfs-filer]', :delayed
    end

    template '/etc/seaweedfs/security.toml' do
      source 'security.toml.erb'
      cookbook 'seaweedfs'
      owner 'root'
      group group
      mode '0640'
      sensitive true
      variables(
        volume_write_key: seaweedfs_key(s3_password, 'volume-write'),
        volume_read_key: seaweedfs_key(s3_password, 'volume-read'),
        filer_write_key: seaweedfs_key(s3_password, 'filer-write'),
        filer_read_key: seaweedfs_key(s3_password, 'filer-read')
      )
      services.each { |svc| notifies :restart, "service[#{svc}]", :delayed }
    end

    template '/etc/seaweedfs/filer.toml' do
      source 'filer.toml.erb'
      cookbook 'seaweedfs'
      owner 'root'
      group group
      mode '0640'
      notifies :restart, 'service[seaweedfs-filer]', :delayed
    end

    if is_master
      template '/etc/default/seaweedfs-master' do
        source 'seaweedfs-master.erb'
        cookbook 'seaweedfs'
        variables(
          ipaddress: ipaddress,
          port: node['seaweedfs']['master_port'],
          peers: master_peers(masters),
          replication: replication,
          volume_size_limit_mb: node['seaweedfs']['volume_size_limit_mb'],
          white_list: s3_nodes.map { |_name, ip| ip }.join(',')
        )
        notifies :restart, 'service[seaweedfs-master]', :delayed
      end
    else
      service 'seaweedfs-master' do
        ignore_failure true
        supports status: true, enable: true
        action [:stop, :disable]
      end

      file '/etc/default/seaweedfs-master' do
        action :delete
      end
    end

    template '/etc/default/seaweedfs-volume' do
      source 'seaweedfs-volume.erb'
      cookbook 'seaweedfs'
      variables(
        ipaddress: ipaddress,
        port: node['seaweedfs']['volume_port'],
        masters: master_peers(masters),
        min_free_space: node['seaweedfs']['min_free_space'],
        white_list: s3_nodes.map { |_name, ip| ip }.join(',')
      )
      notifies :restart, 'service[seaweedfs-volume]', :delayed
    end

    template '/etc/default/seaweedfs-filer' do
      source 'seaweedfs-filer.erb'
      cookbook 'seaweedfs'
      variables(
        ipaddress: ipaddress,
        port: node['seaweedfs']['filer_port'],
        masters: master_peers(masters),
        replication: replication,
        s3_port: node['seaweedfs']['s3_port']
      )
      notifies :restart, 'service[seaweedfs-filer]', :delayed
    end

    unless s3_ready?
      template '/etc/redborder/s3_init_conf.yml' do
        source 's3_init_conf.yml.erb'
        cookbook 'seaweedfs'
        sensitive true
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_bucket: s3_bucket,
          s3_endpoint: s3_endpoint,
          cdomain: cdomain
        )
      end

      template '/etc/redborder/s3_malware_init_conf.yml' do
        source 's3_malware_init_conf.yml.erb'
        cookbook 'seaweedfs'
        sensitive true
        variables(
          s3_malware_user: s3_malware_user,
          s3_malware_password: s3_malware_password,
          s3_malware_bucket: s3_malware_bucket,
          s3_malware_endpoint: s3_malware_endpoint,
          cdomain: cdomain
        )
      end

      template '/root/.s3cfg_initial' do
        source 's3cfg_initial.erb'
        cookbook 'seaweedfs'
        sensitive true
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_endpoint: s3_endpoint,
          cdomain: cdomain
        )
      end
    end

    # When the number of S3 managers changes from 1 to more (or back), the volumes that
    # already exist keep their replication: change it. The missing replicas are copied in
    # every run while there are more S3 managers (nothing to do when all are in place), because
    # the other volume servers may not be up yet when the replication changes.
    # Only the first master does it
    ruby_block 'seaweedfs_replication' do
      block do
        commands = []
        if node['seaweedfs']['replication'] != replication
          commands << "volume.configure.replication -replication #{replication}"
        end
        commands << 'volume.fix.replication -apply' if s3_nodes.size > 1
        if weed_shell(masters, commands)
          node.normal['seaweedfs']['replication'] = replication
          Chef::Log.info("SeaweedFS volumes replication: #{replication}")
        else
          Chef::Log.warn("SeaweedFS volumes replication could not be set to #{replication}")
        end
      end
      action :run
      only_if do
        masters.first == ipaddress &&
          (node['seaweedfs']['replication'] != replication || s3_nodes.size > 1) &&
          service_active?('seaweedfs-master') && service_active?('seaweedfs-volume')
      end
    end

    Chef::Log.info('SeaweedFS cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :add_malware do
  begin
    s3_endpoint = new_resource.s3_endpoint
    s3_malware_endpoint = new_resource.s3_malware_endpoint
    cdomain = get_cdomain

    # The malware identity itself is in /etc/seaweedfs/s3.json (action :add)
    template '/root/.s3cfg_malware_initial' do
      source 's3cfg_malware_initial.erb'
      cookbook 'seaweedfs'
      sensitive true
      variables(
        s3_user: new_resource.malware_access_key_id,
        s3_password: new_resource.malware_secret_key_id,
        s3_endpoint: s3_endpoint,
        s3_malware_endpoint: s3_malware_endpoint,
        cdomain: cdomain
      )
    end
  rescue => e
    Chef::Log.error("Error configuring the malware s3 user: #{e.message}")
  end
end

action :add_s3_conf_nginx do
  # Empty when the chef search returns no S3 nodes (e.g. search index down): keep the current
  # s3.conf instead of rendering an upstream without servers, which breaks nginx
  s3_hosts = Array(new_resource.s3_hosts).compact.map(&:to_s).reject(&:empty?)
  cdomain = get_cdomain

  Chef::Log.warn('seaweedfs: no S3 hosts found, /etc/nginx/conf.d/s3.conf is not updated') if s3_hosts.empty?

  service 'nginx' do
    service_name 'nginx'
    ignore_failure true
    supports status: true, reload: true, restart: true, enable: true
    action [:nothing]
  end

  template '/etc/nginx/conf.d/s3.conf' do
    ignore_failure true
    source 's3.conf.erb'
    owner 'nginx'
    group 'nginx'
    mode '0644'
    cookbook 'nginx'
    variables(s3_hosts: s3_hosts, cdomain: cdomain)
    notifies :restart, 'service[nginx]', :delayed
    not_if { s3_hosts.empty? }
  end
end

action :remove do
  begin
    ipaddress = new_resource.ipaddress
    s3_nodes = s3_cluster_nodes(new_resource.managers_with_s3, new_resource.cluster_info, ipaddress)
    other_nodes = s3_nodes.reject { |_name, ip| ip == ipaddress }
    masters = seaweedfs_masters(other_nodes)

    # Move the volumes of this node to the other S3 managers before stopping it.
    # The data in /var/lib/seaweedfs is not removed
    ruby_block 'seaweedfs_evacuate' do
      block do
        node_address = "#{ipaddress}:#{node['seaweedfs']['volume_port']}"
        if weed_shell(masters, ["volume.server.evacuate -node #{node_address} -apply"])
          Chef::Log.info("SeaweedFS volumes moved out of #{node_address}")
        else
          Chef::Log.warn("SeaweedFS volumes could not be moved out of #{node_address}")
        end
      end
      action :run
      only_if { !other_nodes.empty? && service_active?('seaweedfs-volume') }
    end

    %w(seaweedfs-filer seaweedfs-volume seaweedfs-master).each do |svc|
      service svc do
        service_name svc
        ignore_failure true
        supports status: true, enable: true
        action [:stop, :disable]
      end

      file "/etc/default/#{svc}" do
        action :delete
      end
    end

    node.normal['seaweedfs']['replication'] = nil

    Chef::Log.info('SeaweedFS cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  ipaddress = new_resource.ipaddress

  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers && !node['seaweedfs']['registered']
      query = {}
      query['ID'] = "s3-#{node['hostname']}"
      query['Name'] = 's3'
      query['Address'] = ipaddress
      query['Port'] = node['seaweedfs']['s3_port']
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        retries 3
        retry_delay 2
        action :nothing
      end.run_action(:run)

      node.normal['seaweedfs']['registered'] = true

      Chef::Log.info('SeaweedFS S3 service has been registered on consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers && node['seaweedfs']['registered']
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/s3-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['seaweedfs']['registered'] = false

      Chef::Log.info('SeaweedFS S3 service has been deregistered from consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
