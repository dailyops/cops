# Consul

Consul is a distributed, highly-available, and multi-datacenter aware tool for service discovery, configuration, and orchestration. Consul enables rapid deployment, configuration, and maintenance of service-oriented architectures at massive scale

https://www.consul.io/intro/index.html
https://www.katacoda.com/courses/consul

## Notes

* consul agents runing in client or server mode
* consul cluster 1+ server agent, 3 or 5 better
* server agent join in a consensus protocol: maintain a centralized view, reponds client requets
* client agent join in a gossip protocol: discover, health check, forward requet to server agent
* apps communicate only with their local consul agent, http or dns

## Consul with Docker

* typically run a single Consul agent continaer on each host, alongside the Docker daemon
* Consul should always be run with --net=host in Docker because Consul's consensus and gossip protocols are sensitive to delays and packet loss, so the extra layers involved with other networking types are usually undesirable and unnecessary
* Alpine based image with debug tools, curl
* Consul always runs under dumb-init, which handles reaping zombie processes and forwards signals on to all processes running in the container.
* use gosu to run Consul as a non-root "consul" user for better security
* volumes: /consul/data /consul/config CONSUL_LOCAL_CONFIG
* almost run with --net=host 
* agent cluster address:   other Consul agents may contact a given agent
* agent client address: other processes on the host contact Consul in order to make HTTP or DNS requests

