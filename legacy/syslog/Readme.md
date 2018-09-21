# Try rsyslog aggregating log from various clients

build:
  docker compose build

run: 
  docker compose run client 

find client, server, and logstash containerid

  docker exec -ti client_id bash

  # should go server: tail -f /var/log/syslog

  logger -p local0.info  say hi from local0

  # should go logstash by: docker logs -f logstash_id 

  logger -p local1.info  say hi from local1


run logstash in standalone:

  docker run --rm -it -p 1514:1514 --privileged logstash logstash -e 'input { syslog { port => 1514 } } output { stdout { codec => rubydebug } }' 
