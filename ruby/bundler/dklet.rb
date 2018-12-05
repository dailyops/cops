#!/usr/bin/env rundklet
add_note <<~Note
  try bundler features
  https://bundler.io/docs.html
Note

register :appname, "bundler_test"

write_dockerfile <<~Desc
  FROM ruby:2.5-alpine3.7
  LABEL <%=image_labels%>
  WORKDIR /src
  COPY Gemfile Gemfile.lock ./
  #RUN bundle config mirror.https://rubygems.org http://gemstash:9292
  #RUN bundle install --verbose
  RUN bundle install --without development test --verbose
Desc

task :main do
  system_run <<~Desc
    #{dkrun_cmd(named: true)} -d #{docker_image} sleep 3h
  Desc
end

custom_commands do
  desc 'check_lock', 'check shared lockfile by using without'
  def check_lock
    system_run <<~Desc
      #{dklet_script} build
      cd #{script_path}
      bundle install --verbose
      cat Gemfile.lock
    Desc

    container_run <<~Desc, tmp: true
      gem query cgem --local
      bundle show
      echo ==expect: no cgem installed in bundle, but lock file still has info
      cat Gemfile.lock
    Desc
  end
end

__END__
