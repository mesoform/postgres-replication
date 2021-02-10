FROM golang:1.15-alpine AS builder

ENV WALG_VERSION=v0.2.19

ENV _build_deps="wget cmake git build-base bash"

RUN set -ex  \
     && apk add --no-cache $_build_deps \
     && git clone https://github.com/wal-g/wal-g/  $GOPATH/src/wal-g \
     && cd $GOPATH/src/wal-g/ \
     && git checkout $WALG_VERSION \
     && make install \
     && make deps \
     && make pg_build \
     && install main/pg/wal-g / \
     && /wal-g --help

FROM postgres:13.0-alpine

RUN apk add --update iputils htop wget

# Copy compiled wal-g binary from builder
COPY --from=builder /wal-g /usr/local/bin

# Add replication script
COPY scripts/setup-master.sh /docker-entrypoint-initdb.d/
COPY scripts/setup-slave.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*

# Add custom entrypoint
COPY scripts/entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Add wal-g scripts
COPY scripts/make_basebackup.sh
COPY scripts/archive_command.sh
RUN chmod +x /make_basebackup.sh
RUN chmod +x /archive_command.sh

#Healthcheck to make sure container is ready
HEALTHCHECK CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB || exit 1

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["postgres"]

VOLUME ["/var/run/postgresql", "/usr/share/postgresql/", "/var/lib/postgresql/data", "/tmp"]
