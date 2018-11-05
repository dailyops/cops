#!/usr/bin/env rundklet
add_note <<~Note
  auth, token, lease
  https://www.vaultproject.io/docs/concepts/auth.html
  https://www.vaultproject.io/docs/concepts/tokens.html
  https://learn.hashicorp.com/vault/secrets-management/sm-lease
Note

require_relative 'devshared'

custom_commands do
  desc 'auths', 'list auth methods'
  def auths
    container_run <<~Desc
      vault login #{root_token}
      vault auth list -detailed
    Desc
  end

  desc 'secrets', 'list enabled secrets engines'
  def secrets
    container_run <<~Desc
      vault login #{root_token}
      vault secrets list -detailed
    Desc
  end

  desc '', ''
  def authinfo(path = 'token')
    container_run <<~Desc
      vault login #{root_token}
      vault read sys/auth/#{path}/tune
    Desc
  end

  desc '', ''
  option :timeout, type: :boolean, banner: 'wait to timeout'
  def shortttl(ttl = 3)
    # vault token create -help
    cmds = <<~Desc
      vault login #{root_token}
      token=$(vault token create \
        -id=shortttl-#{ttl}-#{Time.now.to_i} \
        -field token \
        -ttl=#{ttl}s)
      VAULT_TOKEN=$token vault token lookup
    Desc
    if options[:timeout]
      cmds << <<~Desc
        sleep #{ttl}
        VAULT_TOKEN=$token vault token lookup
      Desc
    end
    container_run cmds
  end

  desc '', ''
  def longttl(ttl = '24h')
    cmds = <<~Desc
      vault login #{root_token}
      token=$(vault token create \
        -id=shortttl-#{ttl}-#{Time.now.to_i} \
        -field token \
        -ttl=#{ttl})
      VAULT_TOKEN=$token vault token lookup
      vault token revoke $token
      VAULT_TOKEN=$token vault token lookup
    Desc
    container_run cmds
  end

  desc '', ''
  def uselimit(limit = 1)
    cmds = <<~Desc
      vault login #{root_token}
      token=$(vault token create \
        -id=uselimit-#{limit}-#{Time.now.to_i} \
        -use-limit=#{limit} \
        -field token)
    Desc
    1.upto(limit.to_i + 1) do
      cmds << "VAULT_TOKEN=$token vault token lookup\n"
    end
    container_run cmds
  end

  desc '', 'try periodic token'
  # require Root or sudo permission, need client to renew in period!!!
  option :timeout, type: :boolean, banner: 'wait to timeout'
  option :renew, banner: 'renew some extension'
  def periodtoken(period = 8)
    puts "==try with period: #{period}"
    role = "periodtestrole" 
    cmds = <<~Desc
      vault write auth/token/roles/#{role} allowed_policies="default" period="#{period}s"
      token=$(vault token create -role=#{role} \
        -field=token -id=test#{Time.now.to_i}-in-role-#{role})
      sleep 2
      vault token lookup $token
      echo ==get new token: $token
    Desc
    #NOTE: no effect to specify increment
    #vault/auth.rb periodtoken --renew 20
    if options.key?(:renew)
      ext = options[:renew].to_i
      ext = period if ext == 0
      puts "==try renew extend to #{ext}s"
      cmds << <<~Desc
        echo get a new period ttl, so not timeout!
        # -i is -increment
        vault token renew -i #{ext} $token
        #vault token renew $token
        vault token lookup $token
        echo after renew ....
      Desc
    end
    if options[:timeout]
      cmds << <<~Desc
        sleep #{period.to_i - 2}
        VAULT_TOKEN=$token vault token lookup
      Desc
    end
    container_run cmds
  end

  desc '', 'get token info'
  def mytoken
    # current authenticated token info, authenticated status 
    container_run <<~Desc
      vault login #{root_token}
      vault token lookup
      #vault token lookup -accessor b7xxxxx
      #vault token lookup b74cd5xxxx
    Desc
  end

  # how to find associated lease of a token ??? todo
  
  # token get policy of current authenticated token until policy specified
  desc '', ''
  def parenttoken
    container_run <<~Desc
      vault login #{root_token}
      vault token create -ttl=5
      vault token create -ttl=5 -policy=default
    Desc
  end

  desc '', ''
  def orphantoken
    container_run <<~Desc
      vault login #{root_token}
      vault token create -ttl=5 -orphan
    Desc
  end

  # https://www.vaultproject.io/docs/auth/userpass.html
  desc 'userpass_config', ''
  def userpass_config
    # vault write sys/auth/my-auth type=userpass
    # vault path-help auth/my-auth
    container_run <<~Desc
      vault login #{root_token}
      vault auth enable userpass
      vault write auth/userpass/users/testuser \
        password=test123 \
        policies=test
      vault auth list
    Desc
  end

  desc 'userpass_login', '' 
  def userpass_login
    container_run <<~Desc
      vault login --method=userpass \
        username=testuser password=test123 
      vault token lookup
    Desc
    #curl \
      #--request POST \
      #--data '{"password": "test123"}' \
      #http://127.0.0.1:8200/v1/auth/userpass/login/testuser
  end
  
  # https://www.vaultproject.io/docs/auth/github.html
  # most useful for humans: operators or developers using Vault directly via the CLI.
  # friendly to operators and machines
  # vault path-help auth/github/login
  desc 'github_config', ''
  def github_config(user = 'cao7113', org = 'dailyops')
    gtoken = github_access_token
    container_run <<~Desc
      vault login #{root_token}
      # enable it
      vault auth enable github
      # configure with which org?
      vault write auth/github/config organization=#{org}
      # map users/teams to vault core policies
      #vault write auth/github/map/teams/dev value=github-dev-policy
      #todo keys share in teams
      
      # create mappings for a specific user
      #vault write auth/github/map/users/#{user} value=github-test-policy
      #GitHub user called #{user} will be assigned the policy + team policies.
    Desc
    #vault read auth/github/map/users/cao7113
    #vault write -f auth/github/map/users/cao7113
  end

  desc 'github_login', ''
  def github_login
    # * using a GitHub personal access token
    # * any valid GitHub access token with the read:org scope can be used for authentication
    # * If such a token is stolen from a third party service, and the attacker is able to make network calls to Vault, they will be able to log in as the user that generated the access token. When using this method it is a good idea to ensure that access to Vault is restricted at a network level rather than public. 
    gtoken = github_access_token
    container_run <<~Desc
      # will prompt by default if blank
      vault login -method=github token="#{gtoken}"
      sh
    Desc
    #curl \
      #--request POST \
      #--data '{"token": "MY_TOKEN"}' \
      #http://127.0.0.1:8200/v1/auth/github/login
  end

  ##################################################
  #               POLICES
  # https://learn.hashicorp.com/vault/getting-started/policies
  # * built-in policies that cannot be removed. 
  # * the root and default policies are required policies and cannot be deleted. 
  # * The default policy provides a common set of permissions and is included on all tokens by default. 
  # * The root policy gives a token super admin permissions, similar to a root user on a linux machine.
  # * authored in HCL, but are JSON compatible
  # * Policies default to deny, so any access to an unspecified path is not allowed.
  # * vault policy fmt my-policy.hcl
  # * uses a prefix matching system on the API path to determine access control. The most specific defined policy is used, either an exact match or the longest-prefix glob match
  # * Vault itself is the single policy authority

  desc 'policy_add', ''
  def policy_add
    container_run <<~Desc
      vault login #{root_token}
      vault policy delete my-policy
      vault policy write my-policy -<<-EOF
        # Normal servers have version 1 of KV mounted by default, so will need these
        # paths:
        path "secret/*" {
          capabilities = ["create"]
        }
        path "secret/foo" {
          capabilities = ["read"]
        }

        # Dev servers have version 2 of KV mounted by default, so will need these
        # paths:
        path "secret/data/*" {
          capabilities = ["create"]
        }
        path "secret/data/foo" {
          capabilities = ["read"]
        }
      EOF
      vault policy list
      # vault policy read my-policy
    Desc
  end

  desc 'policy_test', ''
  def policy_test
    #To use the policy, create a token and assign it to that policy
    container_run <<~Desc
      vault login #{root_token}
      vault kv metadata delete secret/bar
      #sh
      #vault token create -policy=my-policy
      token=$(vault token create -policy=my-policy -field=token)
      vault login $token
      #Verify that you can write any data to secret/, but only read from secret/foo
      vault kv put secret/bar created_at='#{Time.now}'
      vault kv get secret/bar
      # no permission 
      vault kv put secret/foo robot=beepboop-foo
      # do not have access to sys according to the policy
      vault policy list # or vault secrets list
    Desc
  end

  no_commands do
    def github_access_token
      ENV['GITHUB_VAULT_TOKEN']
    end
  end
end

# Generated with dklet version: 0.1.6

__END__

## token
* VAULT_TOKEN env var
* vault login <atoken> # this command will write the token into ~/.vault-token file by token helper automatically


## Notes
* token is the only vault identification mechanism about vault users
* token like session id in website
* default system ttl: 2764800 seconds = 32 days
* Periodic tokens have a TTL, but no max TTL; therefore they may live for an infinite duration of time so long as they are renewed within their TTL. This is useful for long-running services that cannot handle regenerating a token.
* api auth mainly for machine, cli for humans

Almost everything in Vault has an associated lease, and when the lease is expired, the secret is revoked. Tokens are not an exception. Every non-root token has a time-to-live (TTL) associated with it. When a token expires and it's not renewed, the token is automatically revoked.

Normally, when a token holder creates new tokens, these tokens will be created as children of the original token; tokens they create will be children of them; and so on. When a parent token is revoked, all of its child tokens -- and all of their leases -- are revoked as well. This ensures that a user cannot escape revocation by simply generating a never-ending tree of child tokens.

## How to list tokens

Finally, the only way to "list tokens" is via the auth/token/accessors command, which actually gives a list of token accessors
* token accessor can be used to track token, revoke token

curl -H VAULT_TOKEN=root http://localhost:8200/v1/auth/token/accessors

## renewable
If the token is renewable, Vault can be asked to extend the token validity period using vault token renew or the appropriate renewal endpoint. At this time, various factors come into play. What happens depends upon whether the token is a periodic token (available for creation by root/sudo users, token store roles, or some auth methods), has an explicit maximum TTL attached, or neither.

## periodic token
At issue time, the TTL of a periodic token will be equal to the configured period. At every renewal time, the TTL will be reset back to this configured period, and as long as the token is successfully renewed within each of these periods of time, it will never expire.

## kv store
The Key/Value Backend which stores arbitrary secrets does not issue leases although it will sometimes return a lease duration; see the documentation for more information.

## Lease
Lease IDs are structured in a way that their prefix is always the path where the secret was requested from. This lets you revoke trees of secrets. For example, to revoke all AWS access keys, you can do vault revoke -prefix aws/

## ttl

* global system ttl
  vault read sys/mounts/cubbyhole/tune
  vault write sys/mounts/database/tune default_lease_ttl="8640"
* mount engine ttl
  vault secrets list -detailed
* role ttl
  vault read auth/token/roles/zabbix
* token ttl
* lease ttl

