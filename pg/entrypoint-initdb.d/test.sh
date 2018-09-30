#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER testuser with password 'test';
  CREATE DATABASE test1 with owner testuser;
  GRANT ALL PRIVILEGES ON DATABASE test1 TO testuser;
EOSQL
