#!/usr/bin/env rundklet
add_note <<~Note
  access services on Mac host from containers
  https://docs.docker.com/docker-for-mac/networking/#known-limitations-use-cases-and-workarounds
Note

register_docker_image "nginx:1.15-alpine"

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d -p :80 #{docker_image}
  Desc
end

custom_commands do
  desc '', ''
  def test
    system_run <<~Desc
    Desc
    container_run <<~Desc, image: 'busybox:1.29', tmp: true
      wget -O- http://#{host_domain}:#{host_port_for(80)}
      echo try anything in containers
    Desc
  end

  desc '', ''
  def domain
    puts host_domain
  end

  no_commands do
    def host_domain
      #'docker.for.mac.localhost'
      #'docker.for.mac.host.internal'
      'host.docker.internal' #From 18.03+
    end
  end
end

__END__

https://docs.docker.com/docker-for-mac/networking/
The gateway is also reachable as gateway.docker.internal

/ # ping -c1 gateway.docker.internal
PING gateway.docker.internal (192.168.65.1): 56 data bytes
64 bytes from 192.168.65.1: seq=0 ttl=37 time=0.332 ms

/ # ping -c1 host.docker.internal
PING host.docker.internal (192.168.65.2): 56 data bytes
64 bytes from 192.168.65.2: seq=0 ttl=37 time=0.357 ms
