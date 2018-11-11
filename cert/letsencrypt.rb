#!/usr/bin/env rundklet
add_note <<~Note
  Let’s Encrypt is a free, automated, and open Certificate Authority.
  https://letsencrypt.org/
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
end

__END__

* Let’s Encrypt offers Domain Validation (DV) certificates. We do not offer Organization Validation (OV) or Extended Validation (EV) primarily because we cannot automate issuance for those types of certificates.
* Let’s Encrypt certificates are standard Domain Validation certificates, so you can use them for any server that uses a domain name, like web servers, mail servers, FTP servers, and many more.

## how it works

https://letsencrypt.org/how-it-works/

## Certbot 23k+ stars 
https://certbot.eff.org/
https://github.com/certbot/certbot

## ACME
ACME protocol: Automatic Certificate Management Environment
https://ietf-wg-acme.github.io/acme/draft-ietf-acme-acme.html

ACME clients
https://letsencrypt.org/docs/client-options/

* https://github.com/jsha/minica
