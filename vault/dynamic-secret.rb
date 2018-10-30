#!/usr/bin/env rundklet
add_note <<~Note
  try dynamic secrets
  NOTE: require a vault server & pg server
  https://learn.hashicorp.com/vault/secrets-management/sm-dynamic-secrets
  https://learn.hashicorp.com/vault/secrets-management/db-root-rotation
Note

require_relative 'devshared'

task :main do
  invoke :pg_add_root

  # config vault server with pg dynamic secrets engine
  container_run <<~Desc
    vault login #{root_token}

    # step1: mount at /database
    # vault secrets disable database
    vault secrets enable database &>/dev/null

    # step2: config pg engine 
    # allowed_roles=readonly 
    vault write database/config/postgresql \
      plugin_name=postgresql-database-plugin \
      allowed_roles="*" \
      connection_url=postgresql://{{username}}:{{password}}@#{pghost}:5432/postgres?sslmode=disable \
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
    vault policy write pgreadonly - <<-EOF
      # Get credentials from the database secret engine
      path "database/creds/readonly" {
        capabilities = [ "read" ]
      }
    EOF
  Desc
end

custom_commands do
  desc '', 'verify on pg host'
  def check
    container_run <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy="pgreadonly" -field=token)
      echo ==use token $token
      # login as pgreadonly personas
      vault login $token
      vault read database/creds/readonly -format=json | tee /tmp/a-readonly.json
    Desc

    json = `docker exec #{ops_container} cat /tmp/a-readonly.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}

    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pghost}/postgres"
    container_run <<~Desc, cid: pghost
      psql -c '\\du'
      psql -c '\\conninfo' #{dburl}
    Desc

    if options[:debug]
      puts <<~Desc
        try some ideas:
        * suddently revoke lease: #{hash['lease_id']}
      Desc
      container_run <<~Desc, cid: pghost
        psql #{dburl}
      Desc
    end

    container_run <<~Desc
      vault login #{root_token}
      vault lease renew #{hash['lease_id']}
      vault lease revoke #{hash['lease_id']}
      #vault lease revoke -prefix #{File.dirname(hash['lease_id'])}
    Desc

    container_run <<~Desc, cid: pghost
      psql -c '\\du'
    Desc
  end

  ## todo split this standalone???
  desc '', ''
  def app_config
    ## create appadmin role and policy
    container_run <<~Desc
      vault login #{root_token}

      # todo a good way to manage db structure by a migrator with dynamic password
      # https://stackoverflow.com/questions/50673003/how-to-setup-vault-and-postgres-in-google-cloud-to-have-the-correct-permissions
      # problem: 如何多处并发使用?
      cat <<-SQL >/tmp/appadmin.sql
        CREATE ROLE "{{name}}" WITH CREATEDB CREATEROLE LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
      SQL
      vault write database/roles/appadmin \
        db_name=postgresql \
        creation_statements=@/tmp/appadmin.sql \
        default_ttl=1h max_ttl=24h

      vault policy write appadmin - <<-EOF
        # Get credentials from the database secret engine
        path "database/creds/appadmin" {
          capabilities = [ "read" ]
        }
      EOF

      ## create appadmin token user
      token=$(vault token create -policy="appadmin" -field=token)
      echo ==use token $token
      vault login $token
      vault read database/creds/appadmin -format=json | tee /tmp/appadmin.json
    Desc

    ## parse the appadmin db user for the db app
    json = `docker exec #{ops_container} cat /tmp/appadmin.json`
    require 'json'
    # todo save this to revoke
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}
    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pghost}/postgres"

    # create the db app with a normal db user role
    approle = 'userrole4testdb4vault'
    container_run <<~Desc, cid: pghost
      # clean to get a new app db, do by db root user
      cat <<-SQL | psql
        -- ERROR:  database "testdb4vault" is being accessed by other users
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{app_testdb}' AND pid <> pg_backend_pid();
        drop database if exists #{app_testdb};
      SQL

      # connet to create new db with appadmin user
      cat <<-SQL | psql -a #{dburl}
        create database #{app_testdb}; 
        REVOKE ALL ON DATABASE #{app_testdb} FROM PUBLIC;
        \\c #{app_testdb}
        create table users (id serial, name varchar(50));
        \\d+

        --create a shared role
        create role #{approle};
        GRANT ALL on database #{app_testdb} to "#{approle}";
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "#{approle}";
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "#{approle}";

        --for new created tables? do not work, why
        --ALTER DEFAULT PRIVILEGES FOR role #{approle} IN SCHEMA public GRANT all ON TABLES TO #{approle};
        --ALTER DEFAULT PRIVILEGES FOR role #{approle} IN SCHEMA public GRANT all ON SEQUENCES TO #{approle};
      SQL
    Desc

    # create normal vaulte user role
    container_run <<~Desc
      vault login #{root_token}

      cat <<-SQL >/tmp/appuser.sql
        CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' in role #{approle};
      SQL

      # [ERROR] expiration: failed to revoke lease: lease_id=... error="failed to revoke entry: resp: (*logical.Response)(nil) err: pq: column "testdb4vault" does not exist"
      #cat <<-SQL >/tmp/revoke-appuser.sql
        #SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = "#{app_testdb}" and usename = "{{name}}" AND pid <> pg_backend_pid();
        #DROP ROLE IF EXISTS "{{name}}";
      #SQL
      #  --REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM {{name}};
      #  --REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM {{name}};
      #  --REVOKE USAGE ON SCHEMA public FROM {{name}};
      
      vault write database/roles/appuser \
        db_name=postgresql \
        creation_statements=@/tmp/appuser.sql \
        default_ttl=1h max_ttl=24h
      # revocation_statements=@/tmp/revoke-appuser.sql 

      vault policy write app - <<-EOF
        # Get credentials from the database secret engine
        path "database/creds/appuser" {
          capabilities = [ "read" ]
        }
      EOF
    Desc
  end

  desc '', ''
  def app_check
    container_run <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy="app" -field=token)
      echo ==use token $token
      # login as app personas
      vault login $token
      vault read database/creds/appuser -format=json | tee /tmp/app.json
    Desc

    json = `docker exec #{ops_container} cat /tmp/app.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}

    dburl = "postgres://#{dauth['username']}:#{dauth['password']}@#{pghost}/#{app_testdb}"
    container_run <<~Desc, cid: pghost
      # only superuser or owner can drop table?
      cat <<-SQL | psql -a #{dburl}
        delete from users where name = 'vault';
        insert into users (name) values('vault');
        select * from users limit 10;
      SQL
    Desc

    if options[:debug]
      puts <<~Desc
        try some ideas:
        * suddently revoke lease: #{hash['lease_id']}
      Desc
      container_run <<~Desc, cid: pghost
        psql #{dburl}
      Desc
    end

    lease_id = hash['lease_id']
    container_run <<~Desc, cid: pghost
      ps aux | grep appuser
    Desc
    container_run <<~Desc, cid: pghost
      psql -c "\\du"
    Desc

    #require 'byebug'
    #byebug
    container_run <<~Desc
      vault login #{root_token}
      vault lease revoke #{lease_id} 
    Desc

    container_run <<~Desc, cid: pghost
      ps aux | grep appuser
    Desc
    container_run <<~Desc, cid: pghost
      psql -c "\\du"
    Desc
  end

  desc '', ''
  def grant_test
    dbuser = 'testuser1'
    container_run <<~Desc, cid: pghost
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
    container_run <<~Desc, cid: pghost
      cat <<-SQL | psql -a
        drop user if exists "#{root}";
        create user "#{root}" with superuser password '#{pg_root_init_password}';
        COMMENT ON ROLE "#{root}" IS 'vault only #{Dklet::Util.human_timestamp}';
        \\du+
      SQL
    Desc
  end

  #NOTE: only VAULT knows password after rotation!
  # be CAREFUL to use a special root user!
  desc '', ''
  def pg_rotate_root
    container_run <<~Desc
      vault login #{root_token}
      vault write -force database/rotate-root/postgresql
    Desc
  end

  desc '', ''
  def pg_check_root
    container_run <<~Desc, cid: pghost
      psql -a -c '\\conninfo' \
        postgres://#{pg_root_user}:#{pg_root_init_password}@#{pghost}/postgres
    Desc
  end

  no_commands do
    def pghost
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
  end
end
