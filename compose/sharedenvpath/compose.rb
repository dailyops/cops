#!/usr/bin/env rundklet
add_note <<~Note
Note

shared_path =  Pathname("/tmp/sharedtest1")

set_file_for :dockerfile1, <<~Desc
  FROM alpine:3.7
  ENV SHARED_PATH #{shared_path}
  RUN mkdir -p $SHARED_PATH
  WORKDIR $SHARED_PATH
  RUN echo write from dockerfile > hi 
Desc

set_file_for :dockerfile2, <<~Desc
  FROM alpine:3.7
  ENV SHARED_PATH #{shared_path}
  RUN mkdir -p $SHARED_PATH
  WORKDIR $SHARED_PATH
  COPY hi ./hi1
  RUN cat hi1
Desc

write_specfile <<~Desc
  version: '2'
  services:
    app1:
      build:
        context: .
        dockerfile: #{rendered_file_for(:dockerfile1)}
      command: sleep 1h
    app2:
      build:
        context: .
        dockerfile: #{rendered_file_for(:dockerfile2)}
      command: sleep 1h
Desc

task :main do
  system_run <<~Desc
    docker-compose -f #{specfile} up
  Desc
  
  #build_path = '/tmp/tt11'
  #system_run <<~Desc
    #mkdir #{build_path}
    #docker build -f #{rendered_file_for(:dockerfile1)} #{build_path}
    #docker build -f #{rendered_file_for(:dockerfile2)} #{build_path}
    #rm -fr #{build_path}
    #echo expec: not work
  #Desc
end

__END__
