#!/usr/bin/env rundklet
add_note <<~Note
  Try token and lease
  https://learn.hashicorp.com/vault/secrets-management/sm-lease
Note

require_relative 'devshared'

task :main do
  puts root_token
end

custom_commands do
  desc '', 'get token info'
  def mytoken
    container_run <<~Desc
      # get current authenticated token info, authenticated status 
      vault token lookup
      #vault token lookup -accessor b7xxxxx
      #vault token lookup b74cd5xxxx
    Desc
  end

  no_commands do
    def default_ops_container
      vault_container
    end
  end
end

# Generated with dklet version: 0.1.6

__END__

token is the only vault identification mechanism about vault users

Almost everything in Vault has an associated lease, and when the lease is expired, the secret is revoked. Tokens are not an exception. Every non-root token has a time-to-live (TTL) associated with it. When a token expires and it's not renewed, the token is automatically revoked.
