#!/usr/bin/env rundklet
add_note <<~Note
  try vault tools
  https://www.vaultproject.io/api/system/tools.html
Note

require_relative 'devshared'

custom_commands do
  desc 'random', ''
  def random(bs = 3)
    container_run <<~Desc
      #echo '{"format": "hex"}' > payload.json
      echo '{"format": "base64"}' > payload.json
      curl --header "X-Vault-Token: #{root_token}" -X POST \
        --data @payload.json \
        http://localhost:8200/v1/sys/tools/random/#{bs}
      rm payload.json
    Desc
  end

  desc 'hash', ''
  def hash
    container_run <<~Desc
      echo '{"input": "Jfky"}' > payload.json
      curl \
        --header "X-Vault-Token: #{root_token}" \
        --request POST \
        --data @payload.json \
        http://localhost:8200/v1/sys/tools/hash/sha2-512
      rm payload.json
    Desc
  end

  no_commands do
  end
end
