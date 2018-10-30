add_note <<~Note
  Shared devmode config to used in practices
Note

register :ops_container, 'dev_vault_default'

custom_commands do
  no_commands do
    def root_token
      'root'
    end
  end
end
