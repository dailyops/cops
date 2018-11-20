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
    Desc
  end

  desc '', 'To add a CA certificate'
  def install(certfile)
    if Dklet::Util.on_mac?
      system_run <<~Desc
        security add-trusted-cert -r trustRoot #{certfile}
      Desc
    else
      puts "Todo to support #{RUBY_PLATFORM}"
    end
  end
end

__END__
