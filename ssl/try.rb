#!/usr/bin/env rundklet
add_note <<~Note
  try ssl
Note

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices
write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d #{docker_image}
  Desc
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
      #{dktmprun} echo hi container #{container_name}
    Desc
  end
end

# Generated with dklet version: 0.1.4
__END__

https://tls.ulfheim.net/
https://www.websecurity.symantec.com/security-topics/what-is-ssl-tls-https
https://github.com/paulczar/omgwtfssl

## Notes
* SSL: Secure Sockets Layer, in short, it's the standard technology for keeping an internet connection secure and safeguarding any sensitive data that is being sent between two systems, preventing criminals from reading and modifying any information transferred, including potential personal details.
* TLS (Transport Layer Security) is just an updated, more secure, version of SSL. We still refer to our security certificates as SSL because it is a more commonly used term
* how it works 
  https://www.websecurity.symantec.com/security-topics/how-does-ssl-handshake-work
* HSTS: HTTP Strict Transport Security, is a standard that protects your website visitors by ensuring they are connected over HTTPS. Make sure that all connections are only accessible via HTTPS and include HSTS in the HTTP response reader.
* 10 steps from http to https
  https://www.websecurity.symantec.com/content/dam/websitesecurity/digitalassets/desktop/pdfs/Infographics/10_Steps_Switch_HTTP_to_HTTPS_infographic_en_us.pdf
* PCI for payment security

