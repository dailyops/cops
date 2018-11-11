#!/usr/bin/env rundklet
add_note <<~Note
  How to install CA certificates and PKCS12 key bundles on different platforms
  https://gist.github.com/marians/b6ce3f2307a1a1ece69355a26c0a688a
Note

task :main do
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
      #{dktmprun} echo hi container #{container_name}
    Desc
  end

  desc '', 'To add a CA certificate'
  def macos(certfile)
    system_run <<~Desc
      security add-trusted-cert -r trustRoot #{certfile}
    Desc
  end
end

__END__
