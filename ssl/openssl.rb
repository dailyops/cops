#!/usr/bin/env rundklet
add_note <<~Note
  Familar with OpenSSL: Cryptography and SSL/TLS Toolkit
  https://www.openssl.org/
Note

# https://hub.docker.com/r/governmentpaas/curl-ssl/
write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  ENV PACKAGES "curl openssl ca-certificates"
  RUN apk add --update $PACKAGES && rm -rf /var/cache/apk/*
Desc

custom_commands do
  desc '', ''
  def rand(num = 32)
    container_run <<~Desc, tmp: true
      openssl rand -base64 #{num}
    Desc
  end

  desc '', ''
  def gen
    # http://www.dest-unreach.org/socat/doc/socat-openssltunnel.html
    container_run <<~Desc, tmp: true
      FILENAME=${1:-server}
      #Generate a public/private key pair:
      openssl genrsa -out $FILENAME.key 1024
      #Generate a self signed certificate:
      openssl req -new -key $FILENAME.key -x509 -days 3653 -out $FILENAME.crt
      #You will be prompted for your country code, name etc.; you may quit all prompts with the enter key.
      #Generate the PEM file by just appending the key and certificate files:
      cat $FILENAME.key $FILENAME.crt >$FILENAME.pem
      #The files that contain the private key should be kept secret, thus adapt their permissions:
      chmod 600 $FILENAME.key $FILENAME.pem
    Desc
    #openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        #-subj /CN=localhost \
        #-keyout files/nginx.key -out files/nginx.crt
  end

  desc '', ''
  def digest
    #md5sum <thefile>
    #echo -n 1234 | shasum -a 256
    container_run <<~Desc, tmp: true
      echo 123 | openssl sha256 
    Desc
  end
end

__END__

