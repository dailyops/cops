#!/usr/bin/env rundklet
add_note <<~Note
Note

require_relative 'devshared'

# init config
task :main do
  container_run <<~Desc
    vault login #{root_token}
  Desc
end

custom_commands do
  desc '', ''
  def check
    container_run <<~Desc
      vault login #{root_token}
    Desc
  end

  no_commands do
  end
end

__END__

