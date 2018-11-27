#!/usr/bin/env rundklet
add_note <<~Note
  https://github.com/nodejs/docker-node
  docker nodejs
Note

write_dockerfile <<~Desc
  FROM node:10.13-alpine
  LABEL <%=image_labels%>
  WORKDIR /src
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d \
      -p 3000 \
      -v #{script_path}:/src \
      #{docker_image} node server.js
  Desc
end

custom_commands do
  desc 'hi', 'say hi'
  def hi
    system_run <<~Desc
      curl #{host_with_port_for(3000)}
    Desc
  end

  desc 'nodesh', 'interactive mode with node loaded'
  def nodesh
    container_run "node"
  end

  desc 'test', 'test inline'
  def test
    container_run <<~Desc
      cat <<-Script | node
        console.log("Hi Nodejs")
      Script
    Desc
  end

  desc 'npm_version', ''
  def npm_version
    container_run "npm version"
  end

  desc 'es6', 'ES6 support table'
  def es6
    puts <<~Desc
      https://nodejs.org/en/docs/es6/
      https://fhinkel.rocks/six-speed/
      https://node.green/
    Desc
  end

  desc 'v8opts', ''
  def v8opts
    # node --v8-options | grep "in progress"
    container_run "node --v8-options"
  end

  #list all dependencies and respective versions that ship with a specific binary through the process global object. In case of the V8 engine, type the following in your terminal to retrieve its version:
  desc 'deps', ''
  def deps
    container_run "node -p process.versions"
    # https://nodejs.org/en/docs/meta/topics/dependencies/
  end

end

__END__

node --help
node --check
node -i / --interactive
node -r / --require
node -e / -p

NODE_PATH
module search path

https://nodejs.org/en/docs/guides/
