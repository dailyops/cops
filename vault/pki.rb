#!/usr/bin/env rundklet
add_note <<~Note
  try PKI secrets engine
  https://www.vaultproject.io/docs/secrets/pki/index.html
Note

require_relative 'devshared'

# init config
task :main do
  container_run <<~Desc
    vault login #{root_token}

    vault secrets disable pki
    vault secrets enable pki
    # tune to 1 year, 30 days by default 
    vault secrets tune -max-lease-ttl=8760h pki

    vault write pki/root/generate/internal \
      common_name=my-website.com \
      ttl=8760h
    # The returned certificate is purely informative. 
    # The private key is safely stored internally in Vault.
    
    vault write pki/config/urls \
      issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
      crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"
    vault write pki/roles/my-role \
      allowed_domains=my-website.com \
      allow_subdomains=true \
      max_ttl=72h
  Desc
end

custom_commands do
  desc '', ''
  def get
    container_run <<~Desc
      vault login #{root_token}
      vault write pki/issue/my-role \
        common_name=www.my-website.com
    Desc
  end

  desc '', ''
  def doc
    container_run 'vault path-help pki'
  end

  no_commands do
  end
end

__END__

PKI: Public Key Infrastructure Certificate
CRL: Certificate Revocation List
MTLS: 

https://blog.digitalocean.com/vault-and-kubernetes/
http://cuddletech.com/?p=959

https://medium.com/@sufiyanghori/guide-using-hashicorp-vault-to-manage-pki-and-issue-certificates-e1981e7574e
good introduction CA and application on nginx

Vault can accept an existing key pair, or it can generate its own self-signed root. In general, we recommend maintaining your root CA outside of Vault and providing Vault a signed intermediate CA.
