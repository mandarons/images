#!/bin/bash

set -e

# Source environment variables if available
if [ -f /var/run/s6/container_environment ]; then
    set -a
    . /var/run/s6/container_environment
    set +a
fi

# Set default values for PostgreSQL environment variables
PGDATA=${PGDATA:-/var/lib/postgresql/data}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-postgres}

echo "PostgreSQL: Starting initialization process..."

# Check if PostgreSQL data directory exists and is initialized
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "PostgreSQL: Data directory is empty or not initialized. Initializing..."
    
    # Initialize the database cluster
    sudo -u postgres /usr/lib/postgresql/15/bin/initdb \
        --pgdata="$PGDATA" \
        --auth-host=md5 \
        --auth-local=trust \
        --encoding=UTF8 \
        --locale=C.UTF-8
    
    echo "PostgreSQL: Database cluster initialized successfully"
    
    # Configure PostgreSQL to listen on all addresses and port 5432
    sudo -u postgres tee "$PGDATA/postgresql.conf" > /dev/null <<EOF
# PostgreSQL configuration
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB
log_timezone = 'Etc/UTC'
datestyle = 'iso, mdy'
timezone = 'Etc/UTC'
lc_messages = 'C.UTF-8'
lc_monetary = 'C.UTF-8'
lc_numeric = 'C.UTF-8'
lc_time = 'C.UTF-8'
default_text_search_config = 'pg_catalog.english'
EOF
    
    # Configure client authentication
    sudo -u postgres tee "$PGDATA/pg_hba.conf" > /dev/null <<EOF
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
# Allow connections from any IP address
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
EOF
    
    echo "PostgreSQL: Configuration files updated"
    
    # Start PostgreSQL temporarily to create user and database
    echo "PostgreSQL: Starting temporary instance for setup..."
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "$PGDATA" \
        -o "-p 5432" \
        -w start
    
    # Wait for PostgreSQL to be ready
    echo "PostgreSQL: Waiting for database to be ready..."
    until sudo -u postgres /usr/bin/pg_isready -h localhost -p 5432; do
        echo "PostgreSQL: Waiting for database connection..."
        sleep 2
    done
    
    echo "PostgreSQL: Database is ready, creating user and database..."
    
    # Create user and database
    if [ -n "$POSTGRES_USER" ] && [ "$POSTGRES_USER" != "postgres" ]; then
        sudo -u postgres /usr/bin/psql -p 5432 <<-EOSQL
            CREATE USER "$POSTGRES_USER" WITH CREATEDB PASSWORD '$POSTGRES_PASSWORD';
            ALTER USER "$POSTGRES_USER" CREATEDB;
EOSQL
        echo "PostgreSQL: User '$POSTGRES_USER' created successfully"
    fi
    
    if [ -n "$POSTGRES_DB" ] && [ "$POSTGRES_DB" != "postgres" ]; then
        if [ -n "$POSTGRES_USER" ] && [ "$POSTGRES_USER" != "postgres" ]; then
            sudo -u postgres /usr/bin/createdb -p 5432 -O "$POSTGRES_USER" "$POSTGRES_DB"
        else
            sudo -u postgres /usr/bin/createdb -p 5432 "$POSTGRES_DB"
        fi
        echo "PostgreSQL: Database '$POSTGRES_DB' created successfully"
    fi
    
    # Execute init-db.sql scripts if they exist
    if [ -d "/docker-entrypoint-initdb.d" ]; then
        echo "PostgreSQL: Looking for initialization scripts in /docker-entrypoint-initdb.d..."
        for f in /docker-entrypoint-initdb.d/*.sql; do
            if [ -f "$f" ]; then
                echo "PostgreSQL: Executing SQL script: $f"
                if [ -n "$POSTGRES_DB" ]; then
                    sudo -u postgres /usr/bin/psql -p 5432 -d "$POSTGRES_DB" -f "$f"
                else
                    sudo -u postgres /usr/bin/psql -p 5432 -f "$f"
                fi
                echo "PostgreSQL: Script $f executed successfully"
            fi
        done
        
        for f in /docker-entrypoint-initdb.d/*.sh; do
            if [ -f "$f" ]; then
                echo "PostgreSQL: Executing shell script: $f"
                bash "$f"
                echo "PostgreSQL: Script $f executed successfully"
            fi
        done
    fi
    
    # Stop the temporary PostgreSQL instance
    echo "PostgreSQL: Stopping temporary instance..."
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D "$PGDATA" -m fast -w stop
    
    echo "PostgreSQL: Initialization completed successfully"
else
    echo "PostgreSQL: Data directory already initialized, skipping initialization"
fi

echo "PostgreSQL: Initialization process completed"