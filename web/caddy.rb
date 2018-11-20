#!/usr/bin/env rundklet
add_note <<~Note
  Caddy is the HTTP/2 web server with automatic HTTPS.
  https://caddyserver.com/
  https://github.com/mholt/caddy/
  https://hub.docker.com/r/abiosoft/caddy/
Note

write_dockerfile <<~Desc
  FROM abiosoft/caddy:0.11.0-no-stats
  LABEL <%=image_labels%>
Desc
# golang:1.10-alpine based, includes git, filemanager, cors, realip, expires and cache plugins
# custom plugins
#docker build --build-arg \
    #plugins=filemanager,git,linode \
    #github.com/abiosoft/caddy-docker.git

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d \
      -e ACME_AGREE=true \
      -e "CADDYPATH=/etc/caddycerts" \
      -v #{app_volumes}/caddy-data:/etc/caddycerts \
      -v #{script_path}/Caddyfile:/etc/Caddyfile \
      -v #{script_path}/caddysite:/srv \
      -p :2015 -p :80 -p :443 \
      #{docker_image}
    docker port #{container_name}
  Desc
end

custom_commands do
  desc '', ''
  def test
    system_run <<~Desc
      curl http://localhost:#{host_port_for(2015)}
    Desc
  end

  desc '', ''
  def doc
    system <<~Desc
      open https://caddyserver.com/docs
    Desc
  end
end

__END__

* web server with great https support
* in golang

caddy -host example.com

# How to run in container?

# try on a cloud ubuntu
很简单
https://www.digitalocean.com/community/tutorials/how-to-host-a-website-with-caddy-on-ubuntu-16-04

```
   wget https://github.com/mholt/caddy/releases/download/v0.11.0/caddy_v0.11.0_linux_amd64.tar.gz
   tar -xzf caddy*.tar.gz caddy
   sudo mv caddy /usr/local/bin
   caddy -version
   caddy -help
   ulimit -n 8192

   mkdir hsite && cd hsite
   echo hi caddy > index.html

   # point dns to this host
   sudo caddy -agree -host tmp1.cao9.me
   curl -Lv tmp1.cao9.me
 ```
