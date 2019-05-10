#!/usr/bin/env rundklet
add_note <<~Note
  https://github.com/huginn/huginn.git
  https://hub.docker.com/r/huginn/huginn
Note

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices
write_dockerfile <<~Desc
  FROM huginn/huginn:b513fca3b05fb0dde7a2758d22acd3e132178d0c
  LABEL <%=image_labels%>
Desc

task :main do
  system_run <<~Desc
    ##{dkrun_cmd(named: true)} -d #{docker_image} sleep 1d
    #{dkrun_cmd(named: true)} -d \
      -p 3000 \
      -v #{app_volumes}/dbdata:/var/lib/mysql \
      #{docker_image}
  Desc
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
      #{dktmprun} echo hi container #{container_name}
    Desc
  end
end

__END__


percona/pmm-server:1.17.0
