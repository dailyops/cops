#!/usr/bin/env rundklet
add_note <<~Note
  try cubbyhole wrapping token
  per-token private secret storage
  https://learn.hashicorp.com/vault/secrets-management/sm-cubbyhole
  cubbyhole secret engine provides your personal secret store. 
  None, even root can not read your cubbyhole store
Note

require_relative 'devshared'

# config: write demo policy
task :main do
  container_run <<~Desc
    vault login #{root_token}
    vault policy write #{policy_name} - <<-EOF
      # For testing, read-only on secret/dev path
      # NOTE: dev v2
      path "secret/data/dev" {
        capabilities = [ "read" ]
      }
    EOF
    vault policy read #{policy_name}
  Desc
end

custom_commands do
  desc '', ''
  def check
    container_run <<~Desc
      vault login #{root_token}
      vault kv put secret/dev name=geek

      ## Admin side: create wrapping token
      wtoken=$(vault token create -policy=#{policy_name} -wrap-ttl=120 -format json | jq -r .wrap_info.token)
      vault token lookup $wtoken
      echo ==wrapping token: $wtoken

      ## Apps side: unwrap and read secret
      ## default policy user to mock a authenticated user like from github
      token=$(vault token create -policy default -field token)
      vault login $token
      vault kv get secret/dev
      echo should has NO PERMISSION to read!

      # get wrapped token( only once used) from admin
      # unwrap to get cubbyhole-apps token/secret
      ctoken=$(vault unwrap -format=json $wtoken | jq -r .auth.client_token)
      # only once, if error should alert!!!

      # login as cubbyhole token, read secret
      vault login $ctoken
      vault kv get secret/dev
      vault token lookup
    Desc
  end

  desc '', ''
  def onlyself
    container_run <<~Desc
      vault login #{root_token}
      token=$(vault token create -policy default -ttl 1h -field token)
      vault login $token
      vault token lookup

      echo
      echo  ==play with my private cubbyhole store 
      vault write cubbyhole/private secret2=keepsecrethere
      vault read -field secret2 cubbyhole/private

      echo ==login as root to attempt to read cubbyhole secret
      vault login #{root_token}
      vault read cubbyhole/private
      echo should found nothing as other token user
    Desc
  end

  no_commands do
    def policy_name
      "cubbyhole-test-apps"
    end
  end
end

__END__

The cubbyhole secret engine provides your own private secret storage space where no one else can read (including root). This comes handy when you want to store a password tied to your username that should not be shared with anyone.

The cubbyhole secret engine is mounted at the cubbyhole/ prefix by default. The secrets you store in the cubbyhole/ path are tied to your token and all tokens are permitted to read and write to the cubbyhole secret engine by the default policy.


很不错的response wrapping token 设计，基本原理如下：

1 客户端发起请求，带着wrap-ttl, 同时返回一个wrapping token( only once)
2 服务端将response wrap 到cubbyhole store中
3 客户端unwrap wrapping token 获取 原token, 使用新token 发起下面的请求

