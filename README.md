# Postgres HA

## Summary
Postgres database image setup for HA replication with base backups and WAL archiving to GCS and Recovery

## How to use
Variables usage:

To create a MASTER instance as part of a PostgreSQL HA setup set the following variables (set PG_MASTER to true):

      - PG_MASTER=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password               # docker secret with the postgres user password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password   # docker secret with the postgres replica user password
      - HBA_ADDRESS=10.0.0.0/8
      
To create a REPLICA instance as part of a PostgreSQL HA setup set the following variables (set PG_SLAVE to true):

      - PG_SLAVE=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password               # docker secret with the postgres user password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password   # docker secret with the postgres replica user password
      - PG_MASTER_HOST=pg_master # pg_master service name or swarm node private IP where the pg_master service is running
      - HBA_ADDRESS=10.0.0.0/8

To create a standalone PostgreSQL instance set only the following variables (PG_MASTER or PG_SLAVE vars should not be set):

      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password               # docker secret with the postgres user password
      - POSTGRES_DB=testdb

To run backups and WAL archiving to GCS (Google Cloud Storage) set the following variables (backups will be taken on a MASTER or standalone instance):

      - STORAGE_BUCKET=gs://postgresql13/wal-g         # To specify the GCS bucket
      - GCP_CREDENTIALS=/run/secrets/gcp_credentials   # To specify the docker secret with the service account key that has access to the GCS bucket
      
To restore a backup from GCS (Google Cloud Storage) set the following variables (backups will be restored on a MASTER or standalone instance):

      - RESTORE_BACKUP=true                 # Set to true
      - BACKUP_NAME=ab123c4d56e7-28012021   # To specify the name of the GCS backup to be restored (the name corresponds to the container-date when the backup was taken)

See the example in docker-compose-example.yml to create a PostgreSQL HA master/slave setup with base backups and WAL archiving to GCS and Recovery:

```yamlex
version: "3.7"
secrets:
  db_replica_password:
    external: true
  db_password:
    external: true
  gcp_credentials:
    external: true

services:
  pg_master:
    image: mesoform/postgres-ha:13-latest
    volumes:
      - pg_data:/var/lib/postgresql/data
    environment:
      - PG_MASTER=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password
      - HBA_ADDRESS=10.0.0.0/8
      - STORAGE_BUCKET=gs://postgresql13/wal-g
      - GCP_CREDENTIALS=/run/secrets/gcp_credentials
      - RESTORE_BACKUP=true
      - BACKUP_NAME=ab123c4d56e7-28012021
    ports:
      - "5432:5432"
    secrets:
      - source: db_replica_password
        uid: "70"
        gid: "70"
        mode: 0550
      - source: db_password
        uid: "70"
        gid: "70"
        mode: 0550
      - source: gcp_credentials
        uid: "70"
        gid: "70"
        mode: 0550
    networks:
      database:
        aliases:
          - pg_cluster
    deploy:
      placement:
        constraints:
        - node.labels.type == primary
  pg_slave:
    image: mesoform/postgres-ha:13-latest
    volumes:
      - pg_replica:/var/lib/postgresql/data
    environment:
      - PG_SLAVE=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password
      - PG_MASTER_HOST=pg_master  # This needs to be the swarm node private IP instead of the service name (pg_master) which resolves to the service IP
      - HBA_ADDRESS=10.0.0.0/8
    secrets:
      - source: db_replica_password
        uid: "70"
        gid: "70"
        mode: 0550
      - source: db_password
        uid: "70"
        gid: "70"
        mode: 0550
    networks:
      database:
        aliases:
          - pg_cluster
    deploy:
      placement:
        constraints:
        - node.labels.type != primary

networks:
  database: {}

volumes:
  pg_data: {}
  pg_replica: {}

```

Run with:

```shell script
docker stack deploy -c docker-compose-example.yml test
```

## Official stuff
- [Contributing](https://github.com/mesoform/terraform-infrastructure-modules/CONTRIBUTING.md)
- [Licence](https://github.com/mesoform/terraform-infrastructure-modules/LICENSE)