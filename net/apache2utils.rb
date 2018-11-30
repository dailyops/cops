#!/usr/bin/env rundklet
add_note <<~Note
  try apache2 utils
Note

write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  RUN apk add --no-cache apache2-utils
Desc

task :main do
  puts <<~Desc
    try apache2-utils with image: #{docker_image}
    htpasswd --help
  Desc
end

custom_commands do
  desc 'passwd', 'try htpasswd'
  def passwd
    container_run <<~Desc, tmp: true
      #htpasswd --help
      htpasswd -nbm admin admin
      htpasswd -nbm test test
    Desc
  end
end

__END__
