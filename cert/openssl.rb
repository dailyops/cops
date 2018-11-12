#!/usr/bin/env rundklet
add_note <<~Note
  Familar with OpenSSL: Cryptography and SSL/TLS Toolkit
  https://www.openssl.org/
  https://wiki.openssl.org/index.php/Command_Line_Utilities
  https://www.digicert.com/ssl-support/openssl-quick-reference-guide.htm
Note

register :appname, :openssl

# https://hub.docker.com/r/governmentpaas/curl-ssl/
write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  ENV PACKAGES "curl openssl ca-certificates"
  RUN apk add --update $PACKAGES && rm -rf /var/cache/apk/*
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d \
      -v #{app_volumes}:/certs \
      #{docker_image} sleep 3d
  Desc
end

custom_commands do
  desc '', ''
  def selfsign
    container_run <<~Desc
      # step1: gen key
      openssl genrsa -out server.key 1024
      #openssl genrsa      #generate 2048 bits PRIVATE key
      #openssl genrsa -h   # for help
      #openssl genrsa 125  # unsafe less than 1024
      
      #-des3 will hint to set a passphrase!
      #openssl genrsa -des3 -out server.key 1024
      #can remove passphrase as following:
      #cp server.key server.key.orig
      #openssl rsa -in server.key -out server.key

      # step2: gen csr
      # generate csr, and hint x.509 attrs
      # openssl req -new -key server.key -out server.csr
      openssl req -new -key server.key -out server.csr \
        -subj "/C=CN/ST=Bejing/L=Daxing/O=dailyops/OU=dailyops ca/CN=try.test.com/emailAddress=test@dailyops.com"

      # step3: gen crt
      openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
      ls -l
      echo ==do something you interest:
      sh
    Desc

    # 1.生成私钥
    #$ openssl genrsa -out server.key 2048
    # 2.生成 CSR (Certificate Signing Request)
    #$ openssl req -subj "/C=CN/ST=Tianjin/L=Tianjin/O=Mocha/OU=Mocha Software/CN=test1.sslpoc.com/emailAddress=test@mochasoft.com.cn" -new -key server.key -out server.csr
    # 3.生成自签名证书
    #$ openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
  end

  desc '', ''
  def allinone
    container_run <<~Desc
      mkdir tmp3 && cd tmp3
      openssl req -new -days 365 \
        -newkey rsa:2408 -nodes -keyout server.key \
        -pubkey \
        -subj "/C=CN/ST=Bejing/L=Daxing/O=dailyops/OU=dailyops ca/CN=try.test.com/emailAddress=test@dailyops.com" \
        -x509 -set_serial #{Dklet::Util.human_timestamp} \
        -out server.crt
      openssl x509 -text -in server.crt -noout
      ls -l
      #{'sh' if options[:debug]}
      cd ..
      rm -fr tmp3
    Desc
  end

  desc '', ''
  def localtest
    system_run <<~Desc
      docker cp #{script_path}/localhost.conf #{container_name}:/tmp/localhost.conf
    Desc
    container_run <<~Desc
      cd /certs
      mkdir -p localtest
      cd localtest
      openssl req -batch -x509 -nodes -days 365 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -config /tmp/localhost.conf
      ls -l
    Desc
  end

  desc '', ''
  def rootca(path = "rootca-#{Dklet::Util.human_timestamp}")
    container_run <<~Desc
      cd /certs
      mkdir -p #{path} && ln -s #{path} rootca
      cd rootca

      # 1 gen ca private key
      #openssl genrsa -des3 -out ca.key 4096
      openssl genrsa -out ca.key 4096

      # 2 gen ca cert(self signed) 
      openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=CN/ST=Bejing/L=Daxing/O=dailyops/OU=dailyops CA/CN=dailyops.internal/emailAddress=ca@dailyops.internal"

      ls -l /certs
    Desc
  end

  desc '', ''
  def tryca
    container_run <<~Desc
      cd /tmp

      # openssl genrsa -des3 -out server.key 2048
      openssl genrsa -out server.key 2048
      # sign request
      openssl req -new -key server.key -out server.csr \
        -subj "/C=CN/ST=Bejing/L=Daxing/O=dailyops/OU=dailyops ca/CN=try.test.com/emailAddress=test@dailyops.com"
      # sign cert with ca cert and key
      openssl x509 -req -days 365 -in server.csr -CA /certs/rootca/ca.crt -CAkey /certs/rootca/ca.key -set_serial 01 -out server.crt
      ls -l
      sh
    Desc
  end

  desc '', ''
  def lsca
    container_run <<~Desc
      ls -l /certs/
    Desc
  end

  desc '', ''
  def digest
    #md5sum <thefile>
    #echo -n 1234 | shasum -a 256
    container_run <<~Desc
      echo 123 | openssl sha256 
    Desc
  end

  desc '', ''
  def rand(num = 32)
    container_run <<~Desc
      openssl rand -base64 #{num}
    Desc
  end
end

__END__

X.509

https://tools.ietf.org/html/rfc5280
https://www.openssl.org/docs/man1.1.0/apps/x509.html
The x509 command is a multi purpose certificate utility. It can be used to display certificate information, convert certificates to various forms, sign certificate requests like a "mini CA" or edit certificate trust settings.

* 直接输入openssl进入命令行交互模式，提供了很多子命令
* 自签名证书：自签名指Issuer 和 Subject 是一样的, 无法被撤销
* 自签名CA证书：自签一个root CA 证书，然后用这个CA证书再签发多级中间CA（ttl较短，可分类管理，便于控制）

https://www.jianshu.com/p/e5f46dcf4664
