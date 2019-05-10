#!/usr/bin/env rundklet
add_note <<~Note
  mysql
Note

# https://hub.docker.com/_/mysql
write_dockerfile <<~Desc
  FROM mysql:5.7.24
  LABEL <%=image_labels%>
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d #{docker_image} sleep 1d
    # #{compose_cmd} up -d
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
