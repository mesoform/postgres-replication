#!/bin/bash

if [[ -f /usr/local/scripts/initbackup ]]; then
  echo "Running initial base backup"
  rm /usr/local/scripts/initbackup
  /usr/local/scripts/walg_caller.sh backup-push $PGDATA
  /usr/local/scripts/walg_caller.sh wal-push %p
else
  echo "Copying WAL files to cloud storage bucket"
  /usr/local/scripts/walg_caller.sh wal-push %p
fi
