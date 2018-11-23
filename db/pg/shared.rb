require 'json'
# handle postgres user problem
register :docker_exec_opts, '-u postgres'

task :main do
  write_init_config
  write_dbafile

  system <<~Desc
    #{dkrun_cmd(named: true)} -d #{'--restart always' if in_prod?} \
      -p #{ENV['PORT']}:5432 \
      -e POSTGRES_PASSWORD=#{initpwd} \
      -v #{script_path}/conf/postgresql.conf:/etc/postgresql/postgresql.conf \
      -v #{app_volumes}/dbdata:/var/lib/postgresql/data \
      -v #{dbafile.parent}:/docker-entrypoint-initdb.d \
      #{docker_image} -c 'config_file=/etc/postgresql/postgresql.conf'
      # -c 'shared_buffers=256MB' -c 'max_connections=200'
  Desc
  # -u postgres # has permission bugs when volumes mount
end

custom_commands do
  desc 'readycheck', 'check server is ready?'
  def readycheck
    t0 = Time.now
    until system("docker exec #{ops_container} pg_isready > /dev/null")
      puts "waiting for initdb..."
      sleep 1
    end
    puts "wait taken #{Time.now - t0} seconds"
  end

  desc 'psql', 'enter psql session'
  option :dba, type: :boolean, banner: 'use dba user'
  def psql(*args)
    cmds = if options[:dba]
        "psql -U dbauser -a #{args.join(' ')} postgres"
      else
        "psql -a #{args.join(' ')}"
      end
    container_run cmds
  end

  map 'sql' => 'psql'
  desc 'config', 'show init config'
  def config
    pp init_config
  end

  desc 'write_config', 'write init config firstly'
  option :edit, type: :boolean, aliases: [:m] # -e has taken by env
  def write_config
    write_init_config
    system "vi #{init_config_file}" if options[:edit]
    puts "config file: #{init_config_file}"
  end

  desc 'dbaurl [DB]', 'show dba connection url'
  option :host, type: :boolean
  def dbaurl(db = 'postgres')
    h = container_name
    h = host_with_port_for(5432, host_ip: false) if options[:host]
    url = "postgres://#{config_for('dba_user')}:#{config_for('dba_password')}@#{h}/#{db}"
    puts url
  end

  desc 'sampleconf', ''
  def sampleconf
    # debian /usr/share/postgresql/postgresql.conf.sample
    system <<~Desc
      #{dktmprun} cat /usr/local/share/postgresql/postgresql.conf.sample | tee #{script_path}/conf/postgresql.conf.sample
      #{dktmprun} cat /usr/local/share/postgresql/pg_hba.conf.sample | tee #{script_path}/conf/pg_hba.conf.sample
    Desc
  end

  desc 'entrypoint', 'show entrypoint'
  def entrypoint
    system <<~Desc
      #{dktmprun} cat docker-entrypoint.sh
    Desc
  end
 
  desc 'users', 'list users'
  def users
    container_run <<~Desc
      psql -c '\\du'
    Desc
  end

  desc 'dbs', 'list dbs'
  def dbs
    container_run <<~Desc
      psql -c '\\du'
    Desc
  end

  desc 'appuser USER PASSWORD', 'create a dbuser for app eg. rails'
  option :super, type: :boolean, banner: 'is superuser'
  def appuser(user, passwd = nil)
    unless passwd
      passwd = Dklet::Util.gen_password(20)
      passwd1 = ask("Use password: #{passwd} or input new:")
      passwd = passwd1 if passwd1.length > 0
    end
    container_run <<~Desc
      cat <<-SQL | psql
        CREATE USER #{user} with #{'superuser' if options[:super]} CREATEDB PASSWORD '#{passwd}';
      SQL
    Desc
    puts "create user: #{user}:#{passwd}"
  end

  desc '', 'test if password changed after inited'
  def change_password_reboot
    cname = 'pg-test-init-passwd-changed'
    pswd = initpwd
    pswd1 = "#{pswd}-changed"
    system <<~Desc
      docker rm -f #{cname}
      #{dkrun_cmd} -d --name #{cname} -p :5432 \
        -e POSTGRES_PASSWORD=#{pswd1} \
        -v "#{app_volumes}":/var/lib/postgresql/data \
        #{docker_image}
    Desc
    
    t0 = Time.now
    until system("docker exec #{cname} pg_isready > /dev/null")
      puts "waiting for initdb..."
      sleep 1
    end
    puts "wait taken #{Time.now - t0} seconds"

    # use different password to startup, no effect 
    container_run <<~Desc, tmp: true
      psql -c 'show work_mem' postgres://postgres:#{pswd1}@#{cname}/postgres
    Desc
    ## ok, keep old init password 
    container_run <<~Desc, tmp: true
      psql -c 'show work_mem' postgres://postgres:#{pswd}@#{cname}/postgres
    Desc
  end
  
  no_commands do
    def init_config_file
      app_config_for('init-config.json')
    end

    def init_config
      @_config ||= JSON.parse(init_config_file.read) rescue {}
    end

    def config_for(key)
      init_config[key]
    end

    def initpwd
      config_for('init_password')
    end

    def gen_init_config
      if in_dev?
        password = 'password'
        dbapassword = 'password'
      else
        password = Dklet::Util.gen_password(20)
        dbapassword = Dklet::Util.gen_password(20)
      end
      { 
        init_password: password,
        dba_user: 'dbauser',
        dba_password: dbapassword 
      }
    end

    def write_init_config(force: false)
      return if !force && init_config_file.exist?
      init_config_file.write(gen_init_config.to_json)
    end

    def dbafile
      app_volumes.join('initdb.d').join('dba.sql')
    end

    def write_dbafile
      initdb = dbafile.parent
      initdb.mkpath
      unless dbafile.exist?
        dbafile.write <<~Desc
          -- generated by dklet #{Time.now}
          CREATE USER #{config_for('dba_user')} with superuser password '#{config_for('dba_password')}';
        Desc
      end
    end
  end
end

__END__

try master-slave cluster

healthcheck https://github.com/docker-library/healthcheck/blob/master/postgres/docker-healthcheck

drop user "v-token-readonly-55wami8rM5M7vSewJuFC-1540458739";

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER testuser with createdb password 'test';
  CREATE DATABASE test1 with owner testuser;
  GRANT ALL PRIVILEGES ON DATABASE test1 TO testuser;
EOSQL