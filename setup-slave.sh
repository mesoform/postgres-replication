#!/usr/bin/env bash

[[ ! ${PG_SLAVE^^} = TRUE ]] && exit 0

PG_REP_PASSWORD=$(cat "${PG_REP_PASSWORD_FILE}")

if [ ! -s "$PGDATA/PG_VERSION" ]; then
echo "*:*:*:$PG_REP_USER:$PG_REP_PASSWORD" > ~/.pgpass

chmod 0600 ~/.pgpass

until ping -c 1 -W 1 ${PG_MASTER_HOST:?missing environment variable. PG_MASTER_HOST must be set}
    do
        echo "Waiting for master to ping..."
        sleep 1s
done

until pg_basebackup -h "${PG_MASTER_HOST}" -D "${PGDATA}" -U "${PG_REP_USER}" -vP -W
do
  echo "Waiting for master to connect..."
  sleep 1s
done

echo "host replication all ${HBA_ADDRESS} md5" >> "$PGDATA/pg_hba.conf"

set -e

touch "${PGDATA}"/standby.signal

cat > "${PGDATA}"/postgresql.conf <<EOF
primary_conninfo = 'host=$PG_MASTER_HOST port=${PG_MASTER_PORT:-5432} user=$PG_REP_USER password=$PG_REP_PASSWORD'
EOF
chown postgres. "${PGDATA}" -R
chmod 700 "${PGDATA}" -R
fi