require 'bundler'
Bundler.require

$stdout.sync = true
Librato::Metrics.authenticate ENV['LIBRATO_EMAIL'], ENV['LIBRATO_API_KEY']

# Return a list of the InternalIP addresses for nodes in the cluster.
def get_node_ips
  # This uses the kubernetes-provided service token supplied to every container:
  auth_opts = {
    bearer_token: File.read('/var/run/secrets/kubernetes.io/serviceaccount/token')
  }

  ssl_opts = {
    verify_ssl:  OpenSSL::SSL::VERIFY_NONE
  }

  kube_client = Kubeclient::Client.new ENV['KUBE_API_ENDPOINT'], 'v1', ssl_options: ssl_opts, auth_options: auth_opts
  nodes = kube_client.get_nodes
  nodes.map { |n| n.status.addresses.detect { |address| address['type'] == 'InternalIP' }['address'] }
end

# Given a node_ip, fetch its cadvisor stats and then forward them to librato.
def send_node_stats(node_ip)
  metrics_queue = Librato::Metrics::Queue.new

  cadvisor_res = Typhoeus.get("http://#{node_ip}:4194/api/v1.3/docker/")
  data = Oj.load(cadvisor_res.body)

  data.values.each do |container|
    # Skip containers that aren't managed by kube:
    next if container['spec']['labels'].nil?

    # Parse the container name out of the container name auto-generated by kube
    # see https://github.com/kubernetes/heapster/blob/78ff89c01f52c0ab49dac2d356a8371e79482544/sources/datasource/kubelet.go#L156 
    container_name = container['aliases'].first.split('.').first.sub('k8s_','')

    # Join all of this together into a librato source name:
    source_name = ENV['CONTEXT'] + '.' + container['spec']['labels']['io.kubernetes.pod.name'].sub('/', '.') + '.' + container_name

    puts source_name

    stats = container['stats'].last

    # k8s_POD form the virtual network for a pod.  We must collect net stats from this container,
    # since net counters for indvidual pod containers are always 0.  See http://stackoverflow.com/questions/33472741/what-work-does-the-process-in-container-gcr-io-google-containers-pause0-8-0-d
    # for more info.  No need to collect memory and cpu stats for this container.
    if container_name == 'POD'
      metrics_queue.add "kube.network.tx_bytes" => { type: :counter, value: stats['network']['tx_bytes'], source: source_name }
      metrics_queue.add "kube.network.rx_bytes" => { type: :counter, value: stats['network']['rx_bytes'], source: source_name  }
      next
    end

    if stats['cpu']
      cpu_ms = stats['cpu']['usage']['total'] / 1000000
      metrics_queue.add "kube.cpu.usage_ms" => { type: :counter, value: cpu_ms, source: source_name }
    end
    
    if status['memory']
      metrics_queue.add "kube.memory.usage" => { value: stats['memory']['usage'], source: source_name }
      metrics_queue.add "kube.memory.rss"   => { value: stats['memory']['working_set'], source: source_name }
    end
  end

  metrics_queue.submit
end

loop do
  start_time = Time.now

  puts "Run started at #{Time.now}..."
  begin
    get_node_ips.each { |ip| send_node_stats(ip) }
    GC.start
  rescue Exception => e
    puts "Failed with #{e.class}: #{e.message}."
  end

  duration = Time.now - start_time
  puts "Finished in #{'%0.2f' % duration}s."

  wait = 60 - duration
  sleep(wait) if wait > 0
end