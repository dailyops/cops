# metabase

https://github.com/metabase/metabase
https://hub.docker.com/r/metabase/metabase/
https://www.metabase.com/docs/latest/operations-guide/running-metabase-on-docker.html
https://www.metabase.com/docs/latest/troubleshooting-guide/running.html

## Troubleshooting

https://www.metabase.com/troubleshooting/docker/

## Upgrade

https://www.metabase.com/docs/latest/operations-guide/start.html#upgrading-metabase

## Note

* For production installations of Metabase we recommend that users replace the H2 database with a more robust option such as Postgres. This offers a greater degree of performance and reliability when Metabase is running with many users.

`export MB_DB_CONNECTION_URI="postgres://localhost:5432/metabase?user=<username>&password=<password>` 
