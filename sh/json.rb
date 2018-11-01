#!/usr/bin/env rundklet
add_note <<~Note
Note

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices
write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  RUN apk add jq
Desc

custom_commands do
  desc 'try', 'try'
  def try
    container_run <<~Desc, tmp: true
      echo '{"name": "hi"}' | jq .name     # "hi"
      echo '{"name": "hi"}' | jq -r .name  # hi # no quote
    Desc
  end
end

__END__
