#!/usr/bin/env rundklet
add_note <<~Note
  https://github.com/FiloSottile/mkcert
  1w+ stars, zero-config tool to make locally trusted development certificates with any names you'd like.
  main for dev locally
Note

task :main do
  system_run <<~Desc
    which mkcert || brew install mkcert
  Desc
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
    Desc
  end
end

__END__
