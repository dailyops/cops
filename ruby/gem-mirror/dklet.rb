#!/usr/bin/env rundklet
add_note <<~Note
  test gem mirror
Note

#register_net
#register_build_net netname

write_dockerfile <<~Desc
  FROM ruby:2.5-alpine
  LABEL <%=image_labels%>
  ARG GEM_MIRROR=https://rubygems.org
  COPY Gemfile Gemfile ./
  RUN echo ==gem mirror: $GEM_MIRROR && \
      bundle config mirror.https://rubygems.org $GEM_MIRROR && \
      bundle install 
  # --verbose
Desc

task :main, build: false do
  puts "==system gem mirror env: #{ENV['GEM_MIRROR']}"
  #ENV['GEM_MIRROR'] ||= 'http://gems.lh'
  #ENV['GEM_MIRROR'] ||= 'http://gemstash:9200'
  #ENV['GEM_MIRROR'] ||= 'http://localhost:19200'
  #ENV['GEM_MIRROR'] ||= 'http://host.docker.internal:19200'
  #better than above
  ENV['GEM_MIRROR'] ||= 'https://gems.ruby-china.com'
  invoke :build, [], {}
  system_run <<~Desc
    docker run --rm #{docker_image} sh -c 'gem list|sort'
  Desc
end

__END__
