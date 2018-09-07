# docker swarm 实验

## Ref

https://docs.docker.com/engine/swarm/
https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/

## Todo 

* 部署失败时如何查看错误log， swarm log？
journald -f -u docker
docker service ps helloworld

* 知道service 都部署在哪些node上？
docker service ps helloworld

* mac docker 无法连接vm中启动的swarm cluster
  实验

```
~/dev/uboot/dkbox/swarm$ docker swarm join \
>     --token SWMTKN-1-0jxjdx2f1qf87yhadlea290fmfbilmw96kp1i0dyd7t8blmwsu-8ti8pdmmi9i3v7yri3i8d6qp2 \
>     192.168.33.100:2377
Error response from daemon: can't initialize raft node: rpc error: code = 2 desc = could not connect to prospective new cluster member using its advertised address: rpc error: code = 14 desc = grpc: the connection is unavailable
```

## Notes

* create a swarm on manager node

```
docker swarm init --advertise-addr 192.168.33.100
```

* add worker node

```
docker swarm join-token worker
docker swarm join \
  --token SWMTKN-1-4vhse8voizjjyulb0jbwpfjf9g3ukevwj2wyisulw1opnqrcn7-4e23i1wo0dd3j67mav22rqpg1 \
  192.168.33.100:2377
docker swarm join-token manager
docker swarm node ls  # on manager node
```
* add service on manager node

```
docker service create --replicas 1 --name helloworld alpine ping docker.com
docker swarm serivce ls
```

* work with service

```
docker swarm service inspect --pretty helloworld
docker swarm service update helloworld
docker swarm service rm helloworld
```

* scale 

```
docker service scale hellworld=3
```

* node management

  drain a node
