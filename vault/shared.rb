add_note <<~Note
  ruby client to use vault
  https://github.com/hashicorp/vault-ruby
Note

custom_commands do
  desc '', 'open web'
  def web
    # dev mode auto config
    system <<~Desc
      open "#{host_uri}/ui/"
    Desc
  end
  map 'open' => :web

  desc 'login', 'login as a token'
  def login(token=root_token)
    # this token as authenticated token
    container_run <<~Desc
      vault login #{token}
      sh
    Desc
    # how to logout?
    # remove ~/.vault-token file or reset VAULT_TOKEN env-var?
  end
  
  # id like database/creds/appuser/a5dfb8a5-a5ca-b1c9-74e0-d1b65678b48d
  desc 'revoke_lease ID', ''
  def revoke_lease(id)
    container_run <<~Desc
      vault login #{root_token}
      vault lease revoke #{id}
    Desc
  end 

  desc 'rclient', ''
  def rclient
    init_rubyclient
    byebug if options[:debug]
    #puts Vault.sys.mounts
    puts Vault.address
  end

  no_commands do
    def init_rubyclient
      return if @rclient_inited
      # Also reads from ENV["VAULT_ADDR"]
      Vault.address = host_uri
      # Also reads from ENV["VAULT_TOKEN"]
      Vault.token   = root_token
      @rclient_inited = true
    end

    def rclient_run
      init_rubyclient
      if block_given?
        yield
      else
        abort "require block!"
      end
    end
  end
end

__END__

Vault.sys.seal_status
Vault.logical.write("secret/bacon", delicious: true, cooktime: "11")
Vault.logical.read("secret/bacon")

secret = Vault.logical.read("secret/bacon")
secret.data #=> { :cooktime = >"11", :delicious => true }
