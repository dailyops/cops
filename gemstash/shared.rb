register_net
register :service, 'gemstash'
register :service_port, 9292
register :service_url, "http://#{fetch(:service)}:#{fetch(:service_port)}"
register :host_port, 19200
