#!/bin/bash

export GOOGLE_APPLICATION_CREDENTIALS=/root/mesotest-2021.json
export WALG_GS_PREFIX=gs://postgres13/wal-g
export PGUSER=testuser
export PGDATABASE=testdb

wal-g wal-push $1
