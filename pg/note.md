# docker-postgresql

  https://github.com/sameersbn/docker-postgresql
  https://hub.docker.com/r/sameersbn/postgresql/

## 使用host network？

通过设置环境变量PG_TRUST_LOCALNET=true
主机可以无密码访问
psql postgres://postgres@localhost:5432/postgres

## 高级用法

创建slave节点，snapshot，backup

docker run --name postgresql-backup -it --rm \
  --link postgresql-master:master \
  --env 'REPLICATION_MODE=backup' --env 'REPLICATION_SSLMODE=prefer' \
  --env 'REPLICATION_HOST=master' --env 'REPLICATION_PORT=5432'  \
  --env 'REPLICATION_USER=repluser' --env 'REPLICATION_PASS=repluserpass' \
  --volume /srv/docker/backups/postgresql.$(date +%Y%m%d%H%M%S):/var/lib/postgresql \
  sameersbn/postgresql:9.6-2

Once the backup is generated, the container will exit and the backup of the master data will be available at /srv/docker/backups/postgresql.XXXXXXXXXXXX/. Restoring the backup involves starting a container with the data in /srv/docker/backups/postgresql.XXXXXXXXXXXX

version : '2'

services:
  postgresql:
    restart: always
    image: sameersbn/postgresql:9.6-2
    container_name: "pgdb"
    ports:
      - "15432:5432"
    environment:
      - DEBUG=false
      # allow direct access from mac host
      - PG_TRUST_LOCALNET=true
      #- PG_PASSWORD=passw0rd

      - DB_USER=
      - DB_PASS=
      - DB_NAME=
      - DB_TEMPLATE=

      - DB_EXTENSION=

      - REPLICATION_MODE=
      - REPLICATION_USER=
      - REPLICATION_PASS=
      - REPLICATION_SSLMODE=
    volumes:
      - /xxxdata/postgresql:/var/lib/postgresql
    #networks:
      #- host
networks:
  default:
    external:
      name: xxx
