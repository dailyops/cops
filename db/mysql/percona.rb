#!/usr/bin/env rundklet
add_note <<~Note
  https://hub.docker.com/_/percona
Note

write_dockerfile <<~Desc
  FROM percona:8.0
  LABEL <%=image_labels%>
Desc

task :main do
  write_init_config

  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d \
      -e MYSQL_ROOT_PASSWORD=#{init_config['password']} \
      #{docker_image}
  Desc
end

custom_commands do
  desc 'sql', 'sql'
  def sql
    system_run <<~Desc
      docker run --rm -it --link #{container_name}:mysql #{docker_image} \
        sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
    Desc
  end

  private
    def set_init_configs
      if in_dev?
        password = 'password'
      else
        password = Dklet::Util.gen_password(20)
      end
      { 
        password: password
      }
    end
end

__END__

