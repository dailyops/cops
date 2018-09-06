#require 'byebug'
require 'socket'

module NetUtils
  module_function

  def hostname
    Socket.gethostname
  end

  def net_ip
    Addrinfo.ip(hostname).ip_address
  end

  def host_all_ips
    Socket.ip_address_list.map{|intf| intf.ip_address }
  end

  def host_ips
    Socket.ip_address_list.select{ |intf| intf.ipv4? && !intf.ipv4_loopback? }
  end

  def first_private_ipv4 
    Socket.ip_address_list.detect{|intf| intf.ipv4_private? }
  end

  def first_public_ipv4 
    # ipv4_private?
    #Returns true for IPv4 private address (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16). It returns false otherwise.
    Socket.ip_address_list.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private? }
  end
end

class App
  def call(env)
    req = Rack::Request.new(env)
    body = [
      "Hi Rack at #{Time.now}!",
      "request ip: #{req.ip}",
      "host_with_port: #{req.host_with_port}",
      "server hostname: #{NetUtils.hostname}",
      "server ips: #{NetUtils.host_all_ips}"
    ].map{ |l| "#{l}<br/>" }
    headers = {'Content-Type'=>'text/html'}

    puts "==hit #{NetUtils.hostname} at #{NetUtils.net_ip} from request #{req.ip}!"
    [200, headers, body]
  end
end

run App.new
