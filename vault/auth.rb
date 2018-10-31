#!/usr/bin/env rundklet
add_note <<~Note
  try token, auth, lease
  token
  https://www.vaultproject.io/docs/concepts/tokens.html
  https://learn.hashicorp.com/vault/secrets-management/sm-lease
Note

require_relative 'devshared'

custom_commands do
  desc 'auths', 'list auth methods'
  def auths
    container_run <<~Desc
      vault login #{root_token}
      vault auth list
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
  option :renew, type: :boolean, banner: 'renew in a period'
  def periodtoken(period = 6)
    role = "periodtestrole" 
    cmds = <<~Desc
      vault write auth/token/roles/#{role} allowed_policies="default" period="#{period}s"
      token=$(vault token create -role=#{role} \
        -field=token -id=test#{Time.now.to_i}-in-role-#{role})
      sleep 2
      vault token lookup $token
      echo ==get new token: $token
    Desc
    if options[:renew]
      cmds << <<~Desc
        echo get a new period ttl, so not timeout!
        vault token renew -increment=#{4 * period.to_i} $token
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

  # https://www.vaultproject.io/docs/auth/userpass.html
  desc 'userpass_config', ''
  def userpass_config
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
    Desc
    #curl \
      #--request POST \
      #--data '{"password": "test123"}' \
      #http://127.0.0.1:8200/v1/auth/userpass/login/testuser
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
end

# Generated with dklet version: 0.1.6

__END__

* token is the only vault identification mechanism about vault users
* default system ttl: 2764800 seconds = 32 days
* Periodic tokens have a TTL, but no max TTL; therefore they may live for an infinite duration of time so long as they are renewed within their TTL. This is useful for long-running services that cannot handle regenerating a token.

Almost everything in Vault has an associated lease, and when the lease is expired, the secret is revoked. Tokens are not an exception. Every non-root token has a time-to-live (TTL) associated with it. When a token expires and it's not renewed, the token is automatically revoked.
