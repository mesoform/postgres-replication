# postgres-replication

## Summary
Postgres database image setup to be used with HA replication

## How to use
Variables usage:

To create a MASTER instance as part of a PostgreSQL HA setup set the following variables (set PG_MASTER to true):

      - PG_MASTER=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password
      - HBA_ADDRESS=10.0.0.0/8
      
To create a REPLICA instance as part of a PostgreSQL HA setup set the following variables (set PG_SLAVE to true):

      - PG_SLAVE=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password
      - PG_MASTER_HOST=pg_master # pg_master service name or swarm node private IP where the pg_master service is running
      - HBA_ADDRESS=10.0.0.0/8

To create a standalone PostgreSQL instance set only the following variables (PG_MASTER or PG_SLAVE vars should not be set):

      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb

See the example in docker-compose-example.yml to create a PostgreSQL HA master/slave setup: 

```yamlex
version: "3.3"
secrets:
  db_replica_password:
    external: true
  db_password:
    external: true

services:
  pg_master:
    image: mesoform/postgres-ha
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
    networks:
      database:
        aliases:
          - pg_cluster
    deploy:
      placement:
        constraints:
        - node.labels.type == primary
  pg_slave:
    image: mesoform/postgres-ha
    volumes:
      - pg_replica:/var/lib/postgresql/data
    environment:
      - PG_SLAVE=true
      - POSTGRES_USER=testuser
      - PG_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_DB=testdb
      - PG_REP_USER=testrep
      - PG_REP_PASSWORD_FILE=/run/secrets/db_replica_password
      - PG_MASTER_HOST=pg_master  # In some cases this needs to be the swarm node private IP instead of the service name (pg_master) which resolves to the service IP
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