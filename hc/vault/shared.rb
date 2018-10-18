add_note <<~Note
  ruby client to use vault
  https://github.com/hashicorp/vault-ruby
Note

custom_commands do
  desc 'ui', 'open web'
  def ui
    # dev mode auto config
    system <<~Desc
      open "#{host_uri}/ui/"
    Desc
  end

  desc 'login', 'login as root'
  def login
    # hot to get authenticated/login status
    container_run <<~Desc
      vault login #{conf_hash['root_token']}
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
      Vault.token   = get_root_token
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
