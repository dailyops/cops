#!/usr/bin/env rundklet
add_note <<~Note
  try container state after container stop
Note

register_docker_image "nginx:1.15-alpine"

task :main do
  cname = 'test-port'
  system_run <<~Desc
    docker run --name #{cname} -d -p 18181:80 #{docker_image}
    docker stop #{cname}
    docker run --name #{cname}-1 -d -p 18181:80 #{docker_image}

    docker start #{cname} # keep remember raw port
    echo ==expect fail as port has been taken!
    echo ==try something here:
    sh

    docker rm -f #{cname}
    docker rm -f #{cname}-1
  Desc
end

__END__

