#!/usr/bin/env rundklet
add_note <<~Note
  try dynamic secrets
  https://learn.hashicorp.com/vault/secrets-management/sm-dynamic-secrets
  https://learn.hashicorp.com/vault/secrets-management/db-root-rotation

  NOTE: require a vault server & pg server
Note

task :main do
  invoke :pg_add_root

  # config vault server
  run_on :vault, <<~Desc
    vault login #{root_token}

    # step1: mount at /database
    # vault secrets disable database
    vault secrets enable database &>/dev/null

    # step2: config 
    # allowed_roles="*"
    vault write database/config/postgresql \
      plugin_name=postgresql-database-plugin \
      allowed_roles=readonly \
      connection_url=postgresql://{{username}}:{{password}}@#{pg_container}:5432/postgres?sslmode=disable \
      username=#{pg_root_user} \
      password=#{pg_root_init_password}

    # step3: create a role, a role is a logical name that maps to a policy used to generate credentials.
    cat <<-SQL >/tmp/readonly.sql
      CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}"; 
    SQL
    vault write database/roles/readonly \
      db_name=postgresql creation_statements=@/tmp/readonly.sql \
      default_ttl=1h max_ttl=24h

    # step4: add a policy
    cat <<-EOF >/tmp/apps-policy.hcl
      # Get credentials from the database secret engine
      path "database/creds/readonly" {
        capabilities = [ "read" ]
      }
    EOF
    vault policy write apps /tmp/apps-policy.hcl
  Desc
end

custom_commands do
  desc '', 'verify on pg host'
  option :psql, type: :boolean, banner: 'stop on psql session with the new user'
  def verify
    run_on :vault, <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy="apps" -field=token)
      echo ==use apps token $token
      # login as apps personas
      vault login $token
      vault read database/creds/readonly -format=json | tee /tmp/a-readonly.json
    Desc

    json = `docker exec #{vault_container} cat /tmp/a-readonly.json`
    require 'json'
    hash = JSON.parse(json)
    puts hash if options[:debug]
    dauth = hash['data'] || {}

    run_on :pg, <<~Desc
      psql -c '\\du'
      psql -c '\\conninfo' postgres://#{dauth['username']}:#{dauth['password']}@#{pg_container}/postgres
    Desc

    if options[:psql]
      puts <<~Desc
        try some ideas:
        * suddently revoke release: #{hash['lease_id']}
      Desc
      run_on :pg, <<~Desc
        psql postgres://#{dauth['username']}:#{dauth['password']}@#{pg_container}/postgres
      Desc
    end

    run_on :vault, <<~Desc
      vault login #{root_token}
      vault lease renew #{hash['lease_id']}
      vault lease revoke #{hash['lease_id']}
      #vault lease revoke -prefix #{File.dirname(hash['lease_id'])}
    Desc

    run_on :pg, <<~Desc
      psql -c '\\du'
    Desc
  end
  map 'check' => 'verify'

  desc '', ''
  def pg_add_root(root = pg_root_user)
    run_on :pg, <<~Desc
      sqlfile=/tmp/create-vault-pg-root.sql
      cat <<-SQL >$sqlfile
        drop user if exists "#{root}";
        create user "#{root}" with superuser password '#{pg_root_init_password}';
      SQL
      psql -a -f $sqlfile
      psql -c '\\du'
    Desc
  end

  desc '', ''
  def pg_users
    run_on :pg, <<~Desc
      psql -c '\\du'
    Desc
  end

  # 周期性rotate
  desc '', ''
  def pg_rotate_root
    puts "NOTE: after rotated, only vault know the password, so be careful by use a dedicade root user!!!"
    run_on :vault, <<~Desc
      vault login #{root_token}
      vault write -force database/rotate-root/postgresql
    Desc
  end

  desc '', ''
  def pg_check_root
    run_on :pg, <<~Desc
      psql -a -c '\\conninfo' postgres://#{pg_root_user}:#{pg_root_init_password}@#{pg_container}/postgres
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

    def run_on(host, cmds, opts = {})
      cid = send("#{host}_container")
      container_run(cmds, {cid: cid}.merge(opts))
    end
  end
end

# Generated with dklet version: 0.1.4
