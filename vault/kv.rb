#!/usr/bin/env rundklet
add_note <<~Note
  kv, mounted secret/, is the main secret store, enable by default
  https://chairnerd.seatgeek.com/practical-vault-usage/
  https://learn.hashicorp.com/vault/secrets-management/sm-versioned-kv
Note

require_relative 'devshared'

# init config
task :main do
  container_run <<~Desc
    vault login #{root_token}
  Desc
end

custom_commands do
  desc '', ''
  def test
    container_run <<~Desc
      vault login #{root_token}

      vault kv put secret/staging name=staging
      vault kv put secret/staging/data name=staging-data
      echo allow same name key and path

      vault kv put secret/dailyops/staging name=shareup-staging
      vault kv put secret/dailyops/dev name=shareup-staging
      vault kv list secret/dailyops
      echo list all entities in the path
    Desc

    # vault kv get secret/dailyops/dev
    # use above to instead of below DEPRECATED USAGE
    # vault read secret/dailyops/dev
  end

  desc '', ''
  def test2 # on v2
    container_run <<~Desc
      vault login #{root_token}
      #clean: delete key and versions
      vault kv metadata delete secret/job
      
      vault kv put secret/job name="ruby" level="senior"
      vault kv put secret/job name="golang" level="senior"
      vault kv get secret/job
      # just fix part, not overwrite others
      vault kv patch secret/job name="java"

      vault kv get -version=2 -field=name secret/job
      vault kv metadata get secret/job

      vault kv delete -versions="2,3" secret/job
      # restore
      # vault kv undelete -versions=3 secret/job
      
      # permantly destroy
      vault kv destroy -versions=3 secret/job
      vault kv metadata get secret/job
    Desc
  end

  desc '', ''
  def versioned
    container_run <<~Desc
      vault login #{root_token}
      vault secrets list -detailed | awk '{ print $1, $2, $10, $11}'
    Desc
  end

  desc '', ''
  def enable_v2
    container_run <<~Desc
      vault login #{root_token}
      vault kv enable-versioning secret/
    Desc
    # other ways: web, http-api

  end

  desc '', ''
  option :limit, default: 3, banner: 'max versions'
  def config
    container_run <<~Desc
      vault login #{root_token}
      vault read secret/config

      #vault write secret/config max_versions=#{options[:limit]}
      #vault write secret/config cas-required=true
    Desc

    # for a special key
    # vault kv metadata put -max-versions=4 secret/xxx
    # vault kv metadata put -cas-required=true secret/xxx
  end

  no_commands do
  end
end

__END__

v1: static secret
v2: support versioning, default in dev mode, not in other mode
