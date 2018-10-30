#!/usr/bin/env rundklet

require_relative 'devshared'

custom_commands do
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
