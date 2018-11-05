#!/usr/bin/env rundklet
add_note <<~Note
  try approle auth method
  https://www.vaultproject.io/docs/auth/approle.html
  https://www.vaultproject.io/guides/identity/authentication
  https://www.hashicorp.com/blog/authenticating-applications-with-vault-approle
  https://learn.hashicorp.com/vault/identity-access-management/iam-approle-trusted-entities
Note

require_relative 'devshared'

task :main do
  container_run <<~Desc
    vault login #{root_token}

    # enable
    vault auth disable approle
    vault auth enable approle

    echo created a named role
    vault write -force #{rolepath} \
      secret_id_ttl=10m \
      token_num_uses=10 \
      token_ttl=20m \
      token_max_ttl=30m \
      secret_id_num_uses=1
  Desc
end

custom_commands do
  desc '', ''
  def test
    container_run <<~Desc
      #vault login #{root_token}

      roleid=$(vault read -field role_id #{rolepath}/role-id)
      echo ==role id: $roleid

      # get a secret id against this approle
      secretid=$(vault write -field secret_id -f #{rolepath}/secret-id)
      echo ==secret id: $secretid

      # login with both id to get a policyed token
      vault write auth/approle/login \
        role_id=$roleid \
        secret_id=$secretid

      # try again to get a different token
      vault write auth/approle/login \
        role_id=$roleid \
        secret_id=$secretid
      # will fail if more times than secret_id_num_uses param above
    Desc
  end

  no_commands do
    def rolename
      "approle-demo"
    end

    def rolepath
      "auth/approle/role/#{rolename}"
    end
  end
end

__END__

* This auth method is oriented to automated workflows (machines and services), and is less useful for human operators.
* An "AppRole" represents a set of Vault policies and login constraints that must be met to receive a token with those policies

* When authenticating against this auth method's login endpoint, the RoleID is a required argument (via role_id) at all times. By default, RoleIDs are unique UUIDs, which allow them to serve as secondary secrets to the other credential information. However, they can be set to particular values to match introspected information by the client (for instance, the client's domain name).

* secret id: intended to always be secret. (For advanced usage, requiring a SecretID can be disabled via an AppRole's bind_secret_id parameter, allowing machines with only knowledge of the RoleID, or matching other set constraints, to fetch a token). SecretIDs can be created against an AppRole either via generation of a 128-bit purely random UUID by the role itself (Pull mode) or via specific, custom values (Push mode). Similarly to tokens, SecretIDs have properties like usage-limit, TTLs and expirations.
* Role ID and Secret ID are like a username and password that a machine or app uses to authenticate.

* other constraints params
  secret_id_bound_cidrs


Additional Note: Periodic Tokens with AppRole
It probably makes better sense to create AppRole periodic tokens since we are talking about long-running apps that need to be able to renew their token indefinitely.

For more details about AppRole, read the AppRole Pull Authentication guide.

To create AppRole periodic tokens, create your AppRole role with period specified.

Example:

$ vault write auth/approle/role/jenkins policies="jenkins" period="72h"

https://www.vaultproject.io/guides/identity/authentication
