# Postgres HA

## Summary
Postgres database image setup for HA replication with control over backups and WAL archiving to GCS and backup restoration functionality.

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
      
To restore a backup from GCS (Google Cloud Storage) set the following variables (backups can be restored on a MASTER or STANDALONE instance):

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
        - node.labels.type == secondary

networks:
  database: {}

volumes:
  pg_data: {}
  pg_replica: {}

```

Run with:

```shell script
docker stack deploy -c docker-compose-example.yml test_pg13ha
```

## How to upgrade to latest PostgreSQL version

The process consists of running `pg_dumpall` on the current database to get a SQL file containing all data and then importing the dump to an empty standalone postgresql  database running the latest version. Once the import completes stop the database to be upgraded and switch the database volume data and image on the `docker-compose` file with the upgraded one before bringing it back up.

#### Pre-upgrade process

Stop the database to be upgraded and take a consistent copy of the data volume which will later be erased.

#### Upgrade process

1) Run `pg_dumpall` on the database to be upgraded to get a SQL file containing all database data:

```
root@testapp:~# docker exec -it ab1cdef23g4h pg_dumpall -U testuser > /backups/dump-testapp_db_data.sql
```

2) Deploy a new PostgreSQL v13 database (with the same database name and username) on an empty volume which will be used to import the data dump taken on the database to be upgraded (the volume containing the data dump also needs to be shared):

```
root@testapp:~/testapp$ cat docker-compose.pg13.yml 
version: "3.7"

volumes:
  pg13_data:
    name: zones/volumes/pg13_data
    driver: zfs
  dumps:
    name: zones/volumes/dumps
    driver: zfs
secrets:
  db_password:
    external: true
  gcp_credentials:
    external: true
networks:
  database: {}

services:
  pg13:
    image: mesoform/postgres-ha:release-13.1.0-0
    volumes:
      - pg13_data:/var/lib/postgresql/data
      - dumps:/dumps
    environment:
      - POSTGRES_DB=testdb
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password 
      - HBA_ADDRESS=10.0.0.0/8
      - STORAGE_BUCKET=gs://backups/postgres/testdb
      - GCP_CREDENTIALS=/run/secrets/gcp_credentials
    secrets:    
      - source: db_password
      - source: gcp_credentials
    deploy:
      placement:
        constraints:
          - node.labels.storage == primary
```
```
root@testapp:~# docker stack deploy -c docker-compose.pg13.yml pg13db
```

3) Import the data dump to the new database:

```
root@testapp:~/testapp$ sudo docker exec -it bc2defg34h5i /bin/bash

bash-5.0# psql -U testuser -d testdb < /dumps/dump-testapp_db_data.sql
```

4) Verify that the tables of `testuser` have been imported:

```
testapp-# \dt
               List of relations
 Schema |         Name         | Type  | Owner  
--------+----------------------+-------+---------
 public | users                | table | testuser
 public | roles                | table | testuser
 public | status               | table | testuser
 public | systems              | table | testuser
(4 rows)

testapp-# \q
```

5) Stop database to be upgraded and removed data from the volume with old data structure (remember we have a backup copy in case something goes wrong):

```
root@testapp:~# docker stack rm testapp
```
```
root@testapp:/volumes/testapp_db_data# rm -rf *
```

6) Sync upgraded data volume from the PostgreSQL v13 database to the old database data volume:

```
root@testapp:~# rsync -av /volumes/testapp_db13_data/ /volumes/testapp_db_data/
```

7) Edit the original `docker-compose` file to update the database postgres image to v13 and gcp parameters to backup to cloud storage:

```
root@testapp:~/testapp$ cat docker-compose.yml
version: "3.7"

volumes:
  app_data:
    name: zones/volumes/testapp_data
    driver: zfs
  db_data:
    name: zones/volumes/testapp_db_data
    driver: zfs
  db_replica_data:
    name: zones/volumes/testapp_db_replica_data
    driver: zfs
secrets:
  testapp_db_password:
    external: true
  testapp_db_replica_password:
    external: true
  gcp_credentials:
    external: true
networks:
  default:

services:
  app:
    image: testapp/testapp-prod:1.0.0
    volumes:
      - app_data:/testapp
    ports:
      - "1234:1234"
    environment:
      - DB_HOST=db
      - DB_PORT_NUMBER=5432
      - DB_NAME=testdb
      - DB_USERNAME=testuser
    deploy:
      placement:
        constraints:
          - node.labels.storage == primary
  db:
    image: mesoform/postgres-ha:release-13.1.0-0
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      - PG_MASTER=true
      - POSTGRES_DB=testdb
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/testapp_db_password
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/testapp_db_replica_password
      - HBA_ADDRESS=10.0.0.0/8
      - STORAGE_BUCKET=gs://backups/postgres/testapp
      - GCP_CREDENTIALS=/run/secrets/gcp_credentials
    secrets:
      - testapp_db_password
      - testapp_replica_password
      - gcp_credentials
    deploy:
      placement:
        constraints:
          - node.labels.storage == primary
  db_replica:
    image: mesoform/postgres-ha:release-13.1.0-0
    volumes:
      - db_replica_data:/var/lib/postgresql/data
    environment:
      - PG_SLAVE=true
      - POSTGRES_DB=testdb
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/testapp_db_password
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/testapp_db_replica_password
      - HBA_ADDRESS=10.0.0.0/8
      - PG_MASTER_HOST=db
    secrets:
      - testapp_db_password
      - testapp_db_replica_password
    deploy:
      placement:
        constraints:
          - node.labels.storage == secondary
```

8) Deploy application using the edited compose configuration, check status and verify the application is working as expected.

```
docker stack deploy -c docker-compose.yml testapp
```
```
root@testapp:~$ sudo docker stack ps testapp
ID                  NAME                   IMAGE                                                          NODE                DESIRED STATE       CURRENT STATE          ERROR               PORTS                       
wklerj2344jd        testapp_db_replica.1   mesoform/postgres-ha:release-13.1.0-0                          secondary           Running             Running 2 minutes ago                       
lclkerk34kl3        testapp_db.1           mesoform/postgres-ha:release-13.1.0-0                          primary             Running             Running 2 minutes ago                       
mfdk34jll34k        testapp_app.1          testapp/testapp-prod:1.0.0                                     primary             Running             Running 2 minutes ago  
```

## Official stuff

- [Contributing](https://github.com/mesoform/terraform-infrastructure-modules/blob/main/CONTRIBUTING.md)
- [Licence](https://github.com/mesoform/terraform-infrastructure-modules/blob/main/LICENSE)