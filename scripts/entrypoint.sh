#!/bin/bash

export PG_REP_PASSWORD_FILE=$PG_REP_PASSWORD_FILE
export HBA_ADDRESS=$HBA_ADDRESS
export POSTGRES_USER=$POSTGRES_USER
export POSTGRES_DB=$POSTGRES_DB
export PG_REP_USER=$PG_REP_USER
export PG_MASTER=${PG_MASTER:false}
export PG_SLAVE=${PG_SLAVE:false}

if [[ -n "${PG_PASSWORD_FILE}" ]]; then
  echo "Using password file\n"
  POSTGRES_PASSWORD=$(cat "${PG_PASSWORD_FILE}")
  export POSTGRES_PASSWORD
fi

if [[ ${PG_MASTER^^} == TRUE && ${PG_SLAVE^^} == TRUE ]]; then
  echo "Both \$PG_MASTER and \$PG_SLAVE cannot be true"
  exit 1
fi

function take_base_backup() {
    docker_setup_env
    docker_temp_server_start
    echo "Running initial database base backup\n"
    /usr/local/scripts/walg_caller.sh backup-push "$PGDATA"
    docker_temp_server_stop
    unset PGPASSWORD
}

function update_master_conf() {
    echo "Reinitialising config file\n"
    sed -i "s/wal_level =.*$//g" "$config_file"
    sed -i "s/archive_mode =.*$//g" "$config_file"
    sed -i "s/archive_command =.*$//g" "$config_file"
    sed -i "s/max_wal_senders =.*$//g" "$config_file"
    sed -i "s/wal_keep_size =.*$//g" "$config_file"
    sed -i "s/hot_standby =.*$//g" "$config_file"
    sed -i "s/synchronous_standby_names =.*$//g" "$config_file"
    echo
    echo "Setting up replication on master\n"
    docker_process_init_files /docker-entrypoint-initdb.d/*
}

function create_master_db() {
    echo "No existing database detected, proceed to initialisation\n"
    source /usr/local/bin/docker-entrypoint.sh
    docker_setup_env
    docker_create_db_directories
    docker_verify_minimum_env
    ls /docker-entrypoint-initdb.d/ > /dev/null
    docker_init_database_dir
    pg_setup_hba_conf
    export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
    docker_temp_server_start
    docker_setup_db
    echo "Update postgres master configuration\n"
    update_master_conf
    docker_temp_server_stop
    echo 'PostgreSQL init process complete; ready for start up\n'
}

function init_walg_conf() {
  echo "Initialising wal-g script variables\n"
  backup_file=/usr/local/scripts/walg_caller.sh

  sed -i 's@GCPCREDENTIALS@'"$GCP_CREDENTIALS"'@' $backup_file
  sed -i 's@STORAGEBUCKET@'"$STORAGE_BUCKET"'@' $backup_file
  sed -i 's@POSTGRESUSER@'"$POSTGRES_USER"'@' $backup_file
  sed -i 's@POSTGRESDB@'"$POSTGRES_DB"'@' $backup_file
}

if [[ $(id -u) == 0 ]]; then
  # then restart script as postgres user
  # shellcheck disable=SC2128
  echo "Detected running as root user, changing to postgres\n"
  exec su-exec postgres "$BASH_SOURCE" "$@"
fi

if [[ ${1:0:1} == - ]]; then
  set -- postgres "$@"
fi

if [[ $1 == postgres ]]; then
  if [[ ${PG_MASTER^^} == TRUE ]]; then
    init_walg_conf
    config_file=$PGDATA/postgresql.conf
    #If config file does not exist then create and initialise database and replication
    if [[ ! -f $config_file ]]; then
      create_master_db
    fi
    take_base_backup
  elif [[ ${PG_SLAVE^^} == TRUE ]]; then
    echo "Update postgres slave configuration\n"
    /docker-entrypoint-initdb.d/setup-slave.sh
  else
    echo "Setting up standalone PostgreSQL instance\n"
  fi
  echo "Running main postgres entrypoint\n"
  bash /usr/local/bin/docker-entrypoint.sh postgres
fi
