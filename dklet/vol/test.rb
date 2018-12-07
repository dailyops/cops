#!/usr/bin/env rundklet
add_note <<~Note
Note

add_dsl do
  def vol_path
    app_volume_for(:test)
  end
end

write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
  WORKDIR /src
  RUN mkdir -p vol1 && echo hi > vol1/hi
Desc

task :main do
  system_run <<~Desc
    rm -fr #{vol_path}
    #{dkrun_cmd(named: true)} --rm -d \
      -v #{vol_path}:/src/vol1 \
      #{docker_image} sleep 1d
    echo list in #{vol_path}
    ls -al #{vol_path}
  Desc

  container_run <<~Desc
    ls -al /src/vol1
  Desc

  # no hi file?
  # yes, container files removed!
end

custom_commands do
  desc 'try', 'try'
  def try
    system_run <<~Desc
      #{dktmprun} echo hi container #{container_name}
    Desc
  end
end

__END__
