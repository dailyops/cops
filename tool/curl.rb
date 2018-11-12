#!/usr/bin/env rundklet
add_note <<~Note
  handy curl test case
Note

write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  RUN apk add curl jq
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} --rm -d #{docker_image} sleep 2h
  Desc
end

custom_commands do
  desc '', ''
  def try
    container_run <<~Desc
      curl -V
    Desc
  end

  desc '', ''
  def install
    if Dklet::Util.host_os.mac?
      system_run <<~Desc
        brew install curl
      Desc
    end
  end
end

__END__

man curl

curl -LO http://xxx/xx/a.file
curl --digest -Lv --user "user1name:password1" https://www.astarup.com/console/posts
curl -X POST --data "data=xxx" example.com/form.cgi

# common options
 -h/--help
 -v/--verbose # verbose/talkative mode
 -b/--cookie name=value
 -c/--cookie-jar file
 -d/--data name=value
 -F/--form name=value
 -H/--header "X-First-Name: Joe"
 -I/--head    # just header only!
 -L/--location
 -n/--netrc
 -o/--output file
 -s/--silent

# files
 .netrc
 .curlrc
