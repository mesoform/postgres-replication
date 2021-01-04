FROM postgres:13.0-alpine

RUN apk add --update iputils htop lzo pv make libffi-dev openssl-dev gcc
RUN apk add --update --no-cache python3 python3-dev && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools wheel
RUN pip3 install --no-cache --upgrade gevent boto google-cloud-storage
RUN python3 -m pip install wal-e[google]

# Add replication script
COPY setup-master.sh /docker-entrypoint-initdb.d/
COPY setup-slave.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
#Healthcheck to make sure container is ready
HEALTHCHECK CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB || exit 1

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["postgres"]

VOLUME ["/var/run/postgresql", "/usr/share/postgresql/", "/var/lib/postgresql/data", "/tmp"]
