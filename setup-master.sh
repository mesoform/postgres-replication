#!/usr/bin/env bash

[[ ! ${PG_MASTER^^} = TRUE ]] && exit 0

PG_REP_PASSWORD=$(cat "${PG_REP_PASSWORD_FILE}")

set -e
source /usr/local/bin/docker-entrypoint.sh

docker_process_sql <<<"
  DO \$$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='$PG_REP_USER') THEN
      CREATE ROLE $PG_REP_USER WITH REPLICATION PASSWORD '$PG_REP_PASSWORD' LOGIN;
    END IF;
  END
  \$$
"

#"SELECT 1 FROM pg_roles WHERE rolname='USR_NAME'" | grep -q 1 ||

echo "host replication all ${HBA_ADDRESS} md5" >> "$PGDATA/pg_hba.conf"

# replication specific configuration
{
  echo "wal_level = hot_standby"
  echo "archive_mode = on"
  echo "archive_command = 'cd .'"
  echo "max_wal_senders = 5"
  echo "wal_keep_size = 512"
  echo "hot_standby = on"
  echo "synchronous_standby_names = '*'"
} >> "$PGDATA"/postgresql.conf
