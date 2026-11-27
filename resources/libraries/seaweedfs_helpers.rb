require 'openssl'
require 'yaml'

module Seaweedfs
  module Helpers
    def generate_random_key(len)
      chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
      key = ''
      len.times { key << chars[rand(chars.size)] }
      key
    end

    def get_cdomain
      if File.exist?('/etc/redborder/cdomain')
        File.read('/etc/redborder/cdomain').strip
      else
        'redborder.cluster'
      end
    end

    # The S3 service of the cluster is already configured (by the first S3 manager)
    def s3_ready?
      `serf members list`.split("\n").any? { |member| member.include?('s3=ready') }
    end

    # Address of this node in the sync network (serf.sync_net of rb_init_conf.yml), as
    # cookbook-rb-manager does. Used by chef-solo, before ipaddress_sync is known
    def local_sync_ip
      init_conf = YAML.safe_load(File.read('/etc/redborder/rb_init_conf.yml'))
      sync_net = init_conf.is_a?(Hash) ? init_conf.dig('serf', 'sync_net').to_s.sub(%r{/.*}, '') : ''
      return node['ipaddress'] if sync_net.empty?

      route = `ip route get #{sync_net} 2>/dev/null`.lines.first.to_s.split
      src = route.index('src')
      src && route[src + 1] ? route[src + 1] : node['ipaddress']
    rescue StandardError
      node['ipaddress']
    end

    # [[name, ip], ...] of the S3 managers, in the order of managers_with_s3. This node is
    # always included (it is the only one while it is configured by chef-solo). Nodes are
    # compared by address: in chef-solo node.name is the FQDN, not the manager name
    def s3_cluster_nodes(managers_with_s3, cluster_info, ipaddress)
      nodes = managers_with_s3.map do |name|
        ip = cluster_info.dig(name, 'ipaddress_sync')
        ip = ipaddress if (ip.nil? || ip.empty?) && name == node.name
        [name, ip]
      end
      nodes.reject! { |_name, ip| ip.nil? || ip.empty? }
      nodes.uniq! { |_name, ip| ip }
      nodes << [node.name, ipaddress] unless nodes.any? { |_name, ip| ip == ipaddress }
      nodes
    end

    # Raft needs an odd number of masters: 1 with 1 or 2 S3 managers, 3 (max_masters) with more
    def seaweedfs_masters(s3_nodes)
      count = s3_nodes.size >= 3 ? node['seaweedfs']['max_masters'] : 1
      s3_nodes.first(count).map { |_name, ip| ip }
    end

    # 000: one copy. 001: one more copy in another volume server (manager) of the same rack
    def seaweedfs_replication(s3_nodes)
      s3_nodes.size > 1 ? '001' : '000'
    end

    # JWT key of the security.toml, the same in every node: derived from the S3 secret of the
    # cluster, a different one for each use
    def seaweedfs_key(secret, use)
      OpenSSL::HMAC.hexdigest('SHA256', secret, "seaweedfs-jwt-#{use}")
    end

    def master_peers(masters)
      masters.map { |ip| "#{ip}:#{node['seaweedfs']['master_port']}" }.join(',')
    end

    def weed_shell(masters, commands)
      script = "lock\n#{commands.join("\n")}\nunlock\n"
      IO.popen(['/usr/bin/weed', 'shell', "-master=#{master_peers(masters)}"], 'r+', err: [:child, :out]) do |io|
        io.write(script)
        io.close_write
        output = io.read
        Chef::Log.info("weed shell: #{output}")
      end
      $?.success?
    end

    def service_active?(service)
      system("systemctl is-active #{service} --quiet")
    end
  end
end
