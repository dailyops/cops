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
      # kv v2 in dev mode
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
      # * the secret has been generated into cubbyhole engine
      # * even admin donot know the secret behind the wrapping token
      #vault token lookup $wtoken
      echo ==wrapping token: $wtoken

      ## Apps side: unwrap and read secret
      ## mock a normal authenticated user eg. from github
      token=$(vault token create -policy default -field token)
      vault login $token
      vault kv get secret/dev
      echo ==expect: should has NO PERMISSION to read!

      # get wrapped token(only once used) from admin
      # unwrap to get cubbyhole-apps token/secret
      ctoken=$(vault unwrap -format=json $wtoken | jq -r .auth.client_token)
      echo ==get unwrapped token: $ctoken
      # should alert if fail

      #echo ==try twice unwrap...
      #vault unwrap $wtoken
      #Code: 400. Errors: * wrapping token is not valid or does not exist

      # login as cubbyhole token, read secret
      vault login $ctoken
      vault kv get secret/dev
      vault token lookup
    Desc
  end

  desc '', ''
  def check_wrapping_token
    container_run <<~Desc
      vault login #{root_token}
      wtoken=$(vault token create -policy=#{policy_name} -wrap-ttl=120 -format json | jq -r .wrap_info.token)
      vault login $wtoken         
      echo expect: should fail as can not used as login token
      vault token lookup $wtoken  
      echo expect: should fail as used more than once
      vault token lookup # still be root

      wtoken=$(vault token create -policy=#{policy_name} -wrap-ttl=120 -format json | jq -r .wrap_info.token)
      vault token lookup $wtoken 
      vault token lookup $wtoken # can lookup any times, donot affect use limit 
      vault unwrap $wtoken  
      echo expect: should ok
      vault unwrap $wtoken  
      echo expect: should fail as twice

      wtoken=$(vault token create -policy=#{policy_name} -wrap-ttl=1 -format json | jq -r .wrap_info.token)
      sleep 1
      vault unwrap $wtoken  
      echo expect: should fail as wrap ttl timeout
    Desc
  end

  desc '', ''
  def onlyself # in cubbyhole secret engine
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
      echo ==expect: found nothing as other token user
    Desc
  end

  no_commands do
    def policy_name
      "cubbyhole-demo-apps"
    end
  end
end

__END__

The cubbyhole secret engine provides your own private secret storage space where no one else can read (including root). This comes handy when you want to store a password tied to your username that should not be shared with anyone.

The cubbyhole secret engine is mounted at the cubbyhole/ prefix by default. The secrets you store in the cubbyhole/ path are tied to your token and all tokens are permitted to read and write to the cubbyhole secret engine by the default policy.


很不错的response wrapping token 设计，基本原理如下：

https://learn.hashicorp.com/vault/secrets-management/sm-cubbyhole#steps
1 amdin创建带wrap-ttl 的一个wrapping token( only once use)
2 将response wrap 到cubbyhole store中
2.1 将wrapping token 分发给客户端
3 客户端unwrap wrapping token 获取 原token, 使用新token 发起下面的请求
获得相应访问权限

设计的根本原因和解决的问题是：
* 创建者只知道wrapping token，但但并不知道真正的token， token是存储在cubbyhole 中的，客户端一旦unwrap认领后，wrappping token就失效了

还是不明白是怎么解决 受信entity如chef、jenkins 重启场景怎么和这个设计关联的

另外： wrapping token 有点类似手机验证码的意思？ 有限时间内有效且只能被使用一次，兑换码??哦也

主要使用场景： 和approle 结合使用以获取secret_id？
