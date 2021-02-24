#!/bin/bash

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

function update_walg_conf() {
  echo "Initialising wal-g script file"
  backup_file=/usr/local/scripts/backup_archive.sh

  sed -i 's@GCPCREDENTIALS@'"$GCP_CREDENTIALS"'@' $backup_file
  sed -i 's@STORAGEBUCKET@'"$STORAGE_BUCKET"'@' $backup_file
  sed -i 's@POSTGRESUSER@'"$POSTGRES_USER"'@' $backup_file
  sed -i 's@POSTGRESDB@'"$POSTGRES_DB"'@' $backup_file
}

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
  sed -i "s/wal_keep_size =.*$//g" "$config_file"
  sed -i "s/hot_standby =.*$//g" "$config_file"
  sed -i "s/synchronous_standby_names =.*$//g" "$config_file"

  source /usr/local/bin/docker-entrypoint.sh
  docker_setup_env
  docker_temp_server_start
  /usr/local/scripts/setup-master.sh
  docker_temp_server_stop

  echo "Adding Postgres base_backup initialisation script"
  {
    echo "#!/bin/bash"
    echo "/usr/local/scripts/backup_archive.sh backup-push $PGDATA"
  } >>/docker-entrypoint-initdb.d/base_backup.sh
  chown -R root:postgres /docker-entrypoint-initdb.d/
  chmod -R 775 /docker-entrypoint-initdb.d/*
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
    update_walg_conf
    update_master_conf
  elif [[ ${PG_SLAVE^^} == TRUE ]]; then
    echo "Update postgres slave configuration"
    /usr/local/scripts/setup-slave.sh
  else
    echo "Setting up standalone PostgreSQL instance"
  fi
  echo "Running main postgres entrypoint"
  bash /usr/local/bin/docker-entrypoint.sh postgres
fi
