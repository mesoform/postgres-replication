#!/bin/bash -x

export PG_REP_PASSWORD_FILE=$PG_REP_PASSWORD_FILE
export HBA_ADDRESS=$HBA_ADDRESS
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_DB=$POSTGRES_DB
export PG_REP_USER=$PG_REP_USER
export PG_MASTER=${PG_MASTER:false}
export PG_SLAVE=${PG_SLAVE:false}
if [[ -n "${PG_PASSWORD_FILE}" ]]; then
  echo "Using password file"
  POSTGRES_PASSWORD=$(cat "${PG_PASSWORD_FILE}")
  export POSTGRES_PASSWORD
fi
if [[ ${PG_MASTER^^} == TRUE && ${PG_SLAVE^^} == TRUE ]]; then
  echo "Both \$PG_MASTER and \$PG_SLAVE cannot be true"
  exit 1
fi

function update_master_conf() {
  # PGDATA is defined in upstream postgres dockerfile
  config_file=$PGDATA/postgresql.conf

  # Check if configuration file exists.
  # If not, it probably means that database is not initialized yet
  if [[ ! -f $config_file ]]; then
    echo "No existing database detected, proceed to initialisation"
    return
  fi

  echo "Update postgres master configuration"

  echo "Reinitialising config file"
  sed -i "s/wal_level =.*$//g" "$config_file"
  sed -i "s/archive_mode =.*$//g" "$config_file"
  sed -i "s/archive_command =.*$//g" "$config_file"
  sed -i "s/max_wal_senders =.*$//g" "$config_file"
  sed -i "s/wal_keep_segments =.*$//g" "$config_file"
  sed -i "s/hot_standby =.*$//g" "$config_file"
  sed -i "s/synchronous_standby_names =.*$//g" "$config_file"

  source /usr/local/bin/docker-entrypoint.sh
  docker_setup_env
  docker_temp_server_start
  /docker-entrypoint-initdb.d/setup-master.sh
  docker_temp_server_stop

}

if [[ $(id -u) == 0 ]]; then
  # then restart script as postgres user
  # shellcheck disable=SC2128
  echo "detected running as root user, changing to postgres"
  exec su-exec postgres "$BASH_SOURCE" "$@"
fi

if [[ ${1:0:1} == - ]]; then
  set -- postgres "$@"
fi

if [[ $1 == postgres ]]; then
  if [[ ${PG_MASTER^^} == TRUE ]]; then
    echo "Update postgres master configuration"
    update_master_conf
  elif [[ ${PG_SLAVE^^} == TRUE ]]; then
    echo "Update postgres slave configuration"
    /docker-entrypoint-initdb.d/setup-slave.sh
  else
    echo "\$PG_MASTER or \$PG_SLAVE need to be true"
  fi
  echo "Running main posgres entrypoint"
  bash /usr/local/bin/docker-entrypoint.sh postgres
fi
