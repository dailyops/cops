# Vault

securely accessing secrets via a unified interface and tight access control
Vault operates as a client/server application
https://www.vaultproject.io/
[vault docker](https://hub.docker.com/_/vault/)
https://github.com/hashicorp/vault
https://www.vaultproject.io/docs/commands/index.html

## todo

* backup and disaster restore strategy
* real usage in daily jenkins+ks practice 

## core concepts

* root token just a special client token with init super admin permissions
* unseal keys are splited parts of a master key used to unseal data store after start/restart
* to use a vault server, require in unsealed state, then vault login with your client token
* token auth method is builtin and can not be disabled
* if restart vault, require do unseal and login again
* Vault supports many auth methods, but they must be enabled before use

## notes

/ # vault status
Error checking seal status: Get https://127.0.0.1:8200/v1/sys/seal-status: http: server gave HTTP response to HTTPS client
/ # export VAULT_ADDR='http://0.0.0.0:8200'
/ # vault status
Key             Value
---             -----
Seal Type       shamir
Sealed          false
Total Shares    1

or 
vault status -address http://0.0.0.0:18200
vault login -address http://0.0.0.0:18200

/ # vault kv put secret/try name=cao
Error making API request.

URL: GET http://0.0.0.0:8200/v1/sys/internal/ui/mounts/secret/try
Code: 500. Errors:

* missing client token

vault login
vault kv put secret/try name=geek

bash autocomplete in client
vault -autocomplete-install

dev server
https://www.vaultproject.io/intro/getting-started/dev-server.html
The dev server is a built-in, pre-configured server that is not very secure but useful for playing with Vault locally.

ops

vault kv put secret/hello name=v1
vault kv put secret/hello name=v2 age=3 excited=yes
vault kv get -format=json secret/hello | jq -r .data.data.excited
vault kv get -field name sceret/hello # v2
vault kv dlete secret/hello

# list secret engines

vault secrets list
vault secrets enable -path=aws aws
vault path-help aws/
vault path-help aws/creds/my-non-existent-role
vault secrets diable aws/
vault path-help secret/

# list auth methods

vault auth enable -path=github github
vault path-help auth/github # note: with auth/ prefix

UI
https://github.com/Caiyeon/goldfish
good

https://github.com/adobe/cryptr
