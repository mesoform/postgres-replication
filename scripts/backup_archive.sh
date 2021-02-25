#!/bin/bash

if [[ -f /usr/local/scripts/initbackup ]]; then
  echo "Running initial base backup"
  /usr/local/scripts/walg_caller.sh backup-push $PGDATA
  rm /usr/local/scripts/initbackup
else
  echo "Copying WAL files to cloud storage bucket"
  /usr/local/scripts/walg_caller.sh wal-push %p
fi
