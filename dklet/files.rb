#!/usr/bin/env rundklet
add_note <<~Note
  test files methods
Note

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices
write_dockerfile <<~Desc
  FROM alpine:3.7
  LABEL <%=image_labels%>
Desc

set_file_for :test1, <<~Desc
  FROM alipine:3.7
Desc

rendering <<~Desc, path: "/tmp/t1"
  test
Desc

task :main, build: false do
  puts rendered_file_for(:test1)
  puts File.read(rendered_file_for(:test1))

  system <<~Desc
    cat #{rendered_file_for(:test1)}
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

__END__
