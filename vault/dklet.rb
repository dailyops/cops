#!/usr/bin/env rundklet
add_note <<~Note
  try vault server

  https://www.katacoda.com/courses/docker-production/vault-secrets
  https://www.melvinvivas.com/secrets-management-using-docker-hashicorp-vault/
Note

register_net
register :appname, :vault
require_relative 'shared'

write_dockerfile <<~Desc
  FROM vault:0.11.1
  LABEL <%=image_labels%>
  RUN apk add curl jq
Desc

task :main do
  if devmode?
    # SKIP_SETCAP to skip setcap Memory Locking
    #-e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:1234'
    #-e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' 
    #-e VIRTUAL_PORT=8200 
    system_run <<~Desc
      #{dkrun_cmd(named: true)} -d \
        --cap-add=IPC_LOCK \
        -e VIRTUAL_HOST=#{proxy_domains(:vault)} \
        -e VAULT_ADDR='http://0.0.0.0:8200' \
        -e VAULT_DEV_LISTEN_TLS_DISABLE=1 \
        -p :8200 \
        #{docker_image} server -dev \
          -dev-root-token-id=#{root_token}
    Desc
    # disable_mlock: true
  else # in production
    #-e 'VAULT_LOCAL_CONFIG={"backend": {"file": {"path": "/vault/file"}}, ...}' 
    system_run <<~Desc
      #{dkrun_cmd(named: true)} -d --restart always \
        --cap-add=IPC_LOCK \
        -p :8200 \
        -e VAULT_ADDR='http://0.0.0.0:8200' \
        -e VIRTUAL_HOST=#{proxy_domains(:vault)} \
        -e VIRTUAL_PORT=8200 \
        -v #{script_path}/config.hcl:/vault/config/config.hcl \
        -v #{app_volumes}:/vault/file \
        #{docker_image} server
    Desc
    
    # check init status??
    sleep 1
    invoke :unseal, [], {}
  end
end

custom_commands do
  desc 'try', 'try command after login'
  option :put, type: :boolean, banner: 'first put info'
  def try
    cmds = []
    cmds << <<~Desc if options[:put]
      vault kv put secret/try name=geek-#{Dklet::Util.human_timestamp}
    Desc
    cmds << <<~Desc
      vault kv get secret/try
      vault kv get -field name secret/try
    Desc
    container_run cmds
  end
  
  desc 'unseal', 'unseal after init'
  def unseal
    container_run <<~Desc
      vault operator unseal #{conf_hash['keys'].first}
      #vault status
    Desc
  end

  desc 'init', 'init vault server'
  def init
    if keysfile.exist?
      if options[:force] || yes?("Already existed #{keysfile}, continue?")
        # avoid dangerous loss
        backup = keysfile.to_s + "-bak-#{Dklet::Util.human_timestamp}"
        FileUtils.cp keysfile, backup
      else
        abort "#{keysfile} existed!"
      end
    end
    ## ways to init vault server
    #// way1: cmd
    #vault operator init -key-shares=1 -key-threshold=1
    #// way2: api
    #// way3: web, it will hint to init if not
    #open http://localhost:8200/ui/
    # avoid {"errors":["Vault is already initialized"]}???
    system <<~Desc
      curl --request POST \
        --data '{"secret_shares": 1, "secret_threshold": 1}' \
        #{host_uri}/v1/sys/init > #{keysfile}
    Desc
  end

  desc 'init_stats', 'query init status'
  def init_status
    system <<~Desc
      curl #{host_uri}/v1/sys/init
    Desc
  end

  desc 'server_info', 'show server config info'
  option :json, type: :boolean, default: false, aliases: ['-j']
  def server_info
    h = {
      address: host_uri,
      config: conf_hash
    }
    if options[:json]
      require 'json'
      puts h.to_json
    else
      pp h
    end
  end
  map 'keys' => 'server_info'

  desc 'hclient', 'connet with host client'
  def hclient
    system_run <<~Desc
      export VAULT_ADDR=#{host_uri}
      vault login #{root_token}
      vault kv get secret/try
    Desc
  end

  no_commands do
    def devmode?
      env == 'dev'
    end

    def host_uri
      "http://#{host_with_port_for(8200)}"
    end
    
    def root_token
      devmode? ? 'root' : conf_hash['root_token']
    end

    def keysfile
      dklet_config_for("init-keys.json") 
    end

    def conf_hash
      if devmode?
        {
          root_token: root_token
        }
      else
        require 'json'
        JSON.parse File.read(keysfile)
      end
    end
  end
end
