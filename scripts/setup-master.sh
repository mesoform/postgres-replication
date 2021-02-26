#!/bin/bash

[[ ! ${PG_MASTER^^} == TRUE ]] && exit 0

PG_REP_PASSWORD=$(cat "${PG_REP_PASSWORD_FILE}")

set -e
source /usr/local/bin/docker-entrypoint.sh

echo "adding replication user \'CREATE ROLE $PG_REP_USER\'"
docker_process_sql <<<"
  DO \$$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='$PG_REP_USER') THEN
      CREATE ROLE $PG_REP_USER WITH REPLICATION PASSWORD '$PG_REP_PASSWORD' LOGIN;
    END IF;
  END
  \$$
"

echo "Adding replication Host-Based Authentication"
if grep "host replication all ${HBA_ADDRESS} md5" "$PGDATA/pg_hba.conf"; then
  echo "'host replication all ${HBA_ADDRESS} md5' already configured"
else
  echo "host replication all ${HBA_ADDRESS} md5" >>"$PGDATA/pg_hba.conf"
fi

echo "Adding replication specific configuration"
{
  echo "wal_level = hot_standby"
  echo "archive_mode = on"
  echo "archive_command = '/usr/local/scripts/walg_caller.sh wal-push %p'"
  echo "max_wal_senders = 5"
  echo "wal_keep_size = 512"
  echo "hot_standby = on"
  echo "synchronous_standby_names = '*'"
} >>"$PGDATA"/postgresql.conf
