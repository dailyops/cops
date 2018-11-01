#!/usr/bin/env rundklet
add_note <<~Note
  try approle auth method
  https://www.vaultproject.io/docs/auth/approle.html
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

      # try login, no role name info
      vault write auth/approle/login \
        role_id=$roleid \
        secret_id=$secretid
      # try again to get a different token
      # Note: relate with secret_id_num_uses config param
      vault write auth/approle/login \
        role_id=$roleid \
        secret_id=$secretid
    Desc
  end

  no_commands do
    def rolename
      "approle-test-role"
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

