#!/usr/bin/env bash

export PG_REP_PASSWORD_FILE=$PG_REP_PASSWORD_FILE
export HBA_ADDRESS=$HBA_ADDRESS
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_DB=$POSTGRES_DB
export PG_REP_USER=$PG_REP_USER
export PG_MASTER=${PG_MASTER:false}
export PG_SLAVE=${PG_SLAVE:false}

function update_conf () {
  repl=$1
  # PGDATA is defined in upstream postgres dockerfile
  config_file=$PGDATA/postgresql.conf

  # Check if configuration file exists. If not, it probably means that database is not initialized yet
  if [ ! -f "$config_file" ]; then
    return
  fi

  # Reinitialize config
  sed -i "s/wal_level =.*$//g" $config_file
  sed -i "s/archive_mode =.*$//g" $config_file
  sed -i "s/archive_command =.*$//g" $config_file
  sed -i "s/max_wal_senders =.*$//g" $config_file
  sed -i "s/wal_keep_segments =.*$//g" $config_file
  sed -i "s/hot_standby =.*$//g" $config_file
  sed -i "s/synchronous_standby_names =.*$//g" $config_file

  if [ "$repl" = true ] ; then
    source /usr/local/bin/docker-entrypoint.sh

    docker_setup_env
    docker_temp_server_start
    [[ ${PG_MASTER^^} = TRUE ]] && /docker-entrypoint-initdb.d/setup-master.sh
    [[ ${PG_SLAVE^^} = TRUE ]] && /docker-entrypoint-initdb.d/setup-slave.sh
    docker_temp_server_stop
  fi
}

if [[ $PG_MASTER == TRUE && $PG_SLAVE == TRUE ]]; then
  echo "Both \$PG_MASTER and \$PG_SLAVE cannot be true"
  exit 1
fi

if [ "$(id -u)" = '0' ]; then
  # then restart script as postgres user
  exec su-exec postgres "$BASH_SOURCE" "$@"
fi

if [ "${1:0:1}" = '-' ]; then
  set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
  repl_enable=true

  # Update postgresql configuration
  update_conf $repl_enable

  # Run the postgresql entrypoint
  bash /usr/local/bin/docker-entrypoint.sh postgres
fi