// vault server -config=xxx-config.hcl

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

/* or
storage "file" {
  path = "/path/to/vault"
}
*/

// activate UI on the same port
ui = true

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

