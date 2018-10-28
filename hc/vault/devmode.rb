#!/usr/bin/env rundklet
add_note <<~Note
  try vault server in dev mode
Note

register_net
register :host_port, 18200
register :root_token, 'root'
require_relative 'shared'

write_dockerfile <<~Desc
  FROM vault:0.11.1
  LABEL <%=image_labels%>
  RUN apk add curl jq
Desc

task :main do
  # SKIP_SETCAP to skip setcap Memory Locking
  #-e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:1234'
  #-e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' 
  #-e VIRTUAL_PORT=8200 
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d \
      --cap-add=IPC_LOCK \
      -e VIRTUAL_HOST=#{proxy_domains('vault.dev')} \
      -e VAULT_ADDR='http://0.0.0.0:8200' \
      -e VAULT_DEV_LISTEN_TLS_DISABLE=1 \
      -p #{fetch(:host_port)}:8200 \
      #{docker_image} server -dev \
        -dev-root-token-id=#{root_token}
  Desc
  # disable_mlock: true
end

custom_commands do
  desc '', ''
  def token
  end

  # todo
  desc '', ''
  def auditlog
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

  ## tokens management
  # * token is the only vault identification mechanism about vault users
  desc 'token_get', 'get token info'
  def token_get
    container_run <<~Desc
      # get current authenticated token info, authenticated status 
      vault token lookup
      #vault token lookup -accessor b7xxxxx
      #vault token lookup b74cd5xxxx
    Desc
  end

  ##################################################
  #               TOOLS
  # https://www.vaultproject.io/api/system/tools.html
  desc 'random', ''
  def random(bs = 3)
    container_run <<~Desc
      #echo '{"format": "hex"}' > payload.json
      echo '{"format": "base64"}' > payload.json
      curl --header "X-Vault-Token: #{root_token}" -X POST \
        --data @payload.json \
        http://#{container_name}:8200/v1/sys/tools/random/#{bs}
      rm payload.json
    Desc
  end

  desc 'hash', ''
  def hash
    container_run <<~Desc
      echo '{"input": "Jfky"}' > payload.json
      curl \
        --header "X-Vault-Token: #{root_token}" \
        --request POST \
        --data @payload.json \
        http://#{container_name}:8200/v1/sys/tools/hash/sha2-512
      rm payload.json
    Desc
  end

  desc 'server_info', 'show server config info'
  def server_info
    h = {
      address: host_uri,
      config: {
        root_token: root_token
      }
    }
    puts h.to_json
  end

  no_commands do
    def host_uri
      "http://localhost:#{fetch(:host_port)}"
    end
    
    def root_token
      fetch(:root_token)
    end
  end
end
