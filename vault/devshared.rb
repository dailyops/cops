add_note <<~Note
  Shared devmode config to used in practices
Note

custom_commands do
  no_commands do
    # keep same with dev !!!
    def vault_container
      'dev_vault_default'
    end

    def root_token
      'root'
    end
  end
end
