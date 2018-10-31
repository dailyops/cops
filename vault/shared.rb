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
    container_run <<~Desc
      vault login #{token}
      sh
    Desc
  end
  # how to logout?? 
  
  # id like database/creds/appuser/a5dfb8a5-a5ca-b1c9-74e0-d1b65678b48d
  desc 'revoke_lease ID', ''
  def revoke_lease(id)
    container_run <<~Desc
      vault login #{root_token}
      vault lease revoke #{id}
    Desc
  end 
  
  # https://www.vaultproject.io/docs/auth/github.html
  # most useful for humans: operators or developers using Vault directly via the CLI.
  # friendly to operators and machines
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

    def github_access_token
      ENV['GITHUB_VAULT_TOKEN']
    end
  end
end

__END__

Vault.sys.seal_status
Vault.logical.write("secret/bacon", delicious: true, cooktime: "11")
Vault.logical.read("secret/bacon")

secret = Vault.logical.read("secret/bacon")
secret.data #=> { :cooktime = >"11", :delicious => true }
