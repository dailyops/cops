#!/usr/bin/env rundklet
add_note <<~Note
  try dynamic secrets
  NOTE: require a vault server & pg server
  https://learn.hashicorp.com/vault/secrets-management/sm-dynamic-secrets
  https://learn.hashicorp.com/vault/secrets-management/db-root-rotation
Note

task :main do
  invoke :pg_add_root

  # config vault server with pg dynamic secrets engine
  container_run_on :vault, <<~Desc
    vault login #{root_token}

    # step1: mount at /database
    # vault secrets disable database
    vault secrets enable database &>/dev/null

    # step2: config pg engine 
    # allowed_roles=readonly 
    vault write database/config/postgresql \
      plugin_name=postgresql-database-plugin \
      allowed_roles="*" \
      connection_url=postgresql://{{username}}:{{password}}@#{pg_container}:5432/postgres?sslmode=disable \
      username=#{pg_root_user} \
      password=#{pg_root_init_password}

    # step3: create a role, 
    # a role is a logical name that maps to a policy used to generate credentials.
    cat <<-SQL >/tmp/readonly.sql
      CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}"; 
    SQL
    vault write database/roles/readonly \
      db_name=postgresql creation_statements=@/tmp/readonly.sql \
      default_ttl=1h max_ttl=24h

    # step4: add a policy
    cat <<-EOF >/tmp/pg-readonly-policy.hcl
      # Get credentials from the database secret engine
      path "database/creds/readonly" {
        capabilities = [ "read" ]
      }
    EOF
    vault policy write pgreadonly /tmp/pg-readonly-policy.hcl
  Desc
end

custom_commands do
  desc '', 'verify on pg host'
  def check
    container_run_on :vault, <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy="pgreadonly" -field=token)
      echo ==use token $token
      # login as pgreadonly personas
      vault login $token
      vault read database/creds/readonly -format=json | tee /tmp/a-readonly.json
    Desc

    json = `docker exec #{vault_container} cat /tmp/a-readonly.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}

    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pg_container}/postgres"
    container_run_on :pg, <<~Desc
      psql -c '\\du'
      psql -c '\\conninfo' #{dburl}
    Desc

    if options[:debug]
      puts <<~Desc
        try some ideas:
        * suddently revoke release: #{hash['lease_id']}
      Desc
      container_run_on :pg, <<~Desc
        psql #{dburl}
      Desc
    end

    container_run_on :vault, <<~Desc
      vault login #{root_token}
      vault lease renew #{hash['lease_id']}
      vault lease revoke #{hash['lease_id']}
      #vault lease revoke -prefix #{File.dirname(hash['lease_id'])}
    Desc

    container_run_on :pg, <<~Desc
      psql -c '\\du'
    Desc
  end

  desc '', ''
  def app_config
    container_run_on :vault, <<~Desc
      vault login #{root_token}

      ## app db admin user
      cat <<-SQL >/tmp/appadmin.sql
        CREATE ROLE "{{name}}" WITH CREATEDB CREATEROLE LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
      SQL
      vault write database/roles/appadmin \
        db_name=postgresql creation_statements=@/tmp/appadmin.sql \
        default_ttl=1h max_ttl=24h

      cat <<-EOF >/tmp/app-policy.hcl
        # Get credentials from the database secret engine
        path "database/creds/appadmin" {
          capabilities = [ "read" ]
        }
      EOF
      vault policy write appadmin /tmp/app-policy.hcl

      token=$(vault token create -policy="appadmin" -field=token)
      echo ==use token $token
      vault login $token
      vault read database/creds/appadmin -format=json | tee /tmp/app.json
    Desc
    json = `docker exec #{vault_container} cat /tmp/app.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}
    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pg_container}/postgres"

    # create db and app db role
    hubrole = 'appuserrole'
    container_run_on :pg, <<~Desc
      # do with superuser
      cat <<-SQL | psql -a
        -- ERROR:  database "testdb4vault" is being accessed by other users
        select pid, usename, application_name, client_addr, client_hostname, client_port, backend_start from pg_stat_activity where datname = '#{app_testdb}';
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{app_testdb}' AND pid <> pg_backend_pid();
        drop database if exists #{app_testdb};
      SQL

      # on app db
      cat <<-SQL | psql -a #{dburl}
        create database #{app_testdb}; 
        REVOKE ALL ON DATABASE #{app_testdb} FROM PUBLIC;
        \\c #{app_testdb}
        create table users (id serial, name varchar(50));
        \\d+

        --create a shared role
        create role #{hubrole};
        GRANT ALL on database #{app_testdb} to "#{hubrole}";
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "#{hubrole}";
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "#{hubrole}";

        --for new created tables? todo
        --ALTER DEFAULT PRIVILEGES FOR role #{hubrole} IN SCHEMA public GRANT all ON TABLES TO #{hubrole};
        --ALTER DEFAULT PRIVILEGES FOR role #{hubrole} IN SCHEMA public GRANT all ON SEQUENCES TO #{hubrole};
      SQL
    Desc

    container_run_on :vault, <<~Desc
      vault login #{root_token}

      ## app normal user
      cat <<-SQL >/tmp/appuser.sql
        CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' in role #{hubrole};
      SQL
      vault write database/roles/appuser \
        db_name=postgresql creation_statements=@/tmp/appuser.sql \
        default_ttl=1h max_ttl=24h

      cat <<-EOF >/tmp/app-policy.hcl
        # Get credentials from the database secret engine
        path "database/creds/appuser" {
          capabilities = [ "read" ]
        }
      EOF
      vault policy write app /tmp/app-policy.hcl
    Desc
  end

  desc '', ''
  def app_check
    container_run_on :vault, <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy="app" -field=token)
      echo ==use token $token
      # login as app personas
      vault login $token
      vault read database/creds/appuser -format=json | tee /tmp/app.json
    Desc

    json = `docker exec #{vault_container} cat /tmp/app.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}

    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pg_container}/#{app_testdb}"
    container_run_on :pg, <<~Desc
      # only superuser or owner can drop table?
      cat <<-SQL | psql -a #{app_testdb}
        drop table if exists blogs;
      SQL
      cat <<-SQL | psql -a #{dburl}
        --create table blogs (id serial, title varchar(100));
        delete from users where name = 'vault';
        insert into users (name) values('vault');
        select * from users limit 10;
      SQL
    Desc

    if options[:debug]
      puts <<~Desc
        try some ideas:
        * suddently revoke release: #{hash['lease_id']}
      Desc
      container_run_on :pg, <<~Desc
        psql #{dburl}
      Desc
    end
  end

  desc 'revoke_release ID', ''
  def revoke_release(id)
    container_run_on :vault, <<~Desc
      vault login #{root_token}
      vault lease revoke #{id}
    Desc
  end 

  desc '', ''
  def grant_test
    dbuser = 'testuser1'
    container_run_on :pg, <<~Desc
      cat <<-SQL | psql 
        -- NOTE: depend on current db for some revoke and grant!!!
        \\c #{app_testdb}

        CREATE user "#{dbuser}";
        GRANT ALL on database #{app_testdb} to "#{dbuser}";

        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "#{dbuser}";
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "#{dbuser}";
      SQL
      cat <<-SQL | psql -U #{dbuser} #{app_testdb}
        \\c
        delete from users where name = 'a';
        insert into users values(1, 'a');
        select * from users;
      SQL
      # clean
      cat <<-SQL | psql 
        \\c #{app_testdb}
        revoke ALL PRIVILEGES ON ALL TABLES IN SCHEMA public from "#{dbuser}";
        revoke ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public from "#{dbuser}";
        revoke ALL on database #{app_testdb} from "#{dbuser}";
        drop user if exists "#{dbuser}";
      SQL
    Desc
  end

  desc '', ''
  def pg_add_root(root = pg_root_user)
    container_run_on :pg, <<~Desc
      cat <<-SQL | psql -a
        drop user if exists "#{root}";
        create user "#{root}" with superuser password '#{pg_root_init_password}';
        COMMENT ON ROLE "#{root}" IS 'only vault used #{Dklet::Util.human_timestamp}';
        \\du+
      SQL
    Desc
  end

  desc '', ''
  def pg_users
    container_run_on :pg, <<~Desc
      psql -c '\\du'
    Desc
  end

  #NOTE: only VAULT knows password after rotation!
  # be CAREFUL to use a special root user!
  desc '', ''
  def pg_rotate_root
    container_run_on :vault, <<~Desc
      vault login #{root_token}
      vault write -force database/rotate-root/postgresql
    Desc
  end

  desc '', ''
  def pg_check_root
    container_run_on :pg, <<~Desc
      psql -a -c '\\conninfo' \
        postgres://#{pg_root_user}:#{pg_root_init_password}@#{pg_container}/postgres
    Desc
  end

  no_commands do
    # keep same with dev !!!
    def vault_container
      'dev_vault_devmode_default'
    end

    # todo use proper permission role
    def root_token
      'root'
    end

    def pg_container
      'dev_pg_default'
    end

    def pg_root_user
      "root4vault"
    end

    def pg_root_init_password
      "vaultpassword"
    end

    def app_testdb
      "testdb4vault"
    end

    def container_run_on(host, cmds, opts = {})
      cid = send("#{host}_container")
      container_run(cmds, {cid: cid}.merge(opts))
    end
  end
end
