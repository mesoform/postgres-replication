#!/bin/bash

echo "Taking Postgres base backup on $PGDATA"
/usr/local/scripts/backup_archive.sh backup-push $PGDATA
