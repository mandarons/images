#!/bin/bash

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
    if [ $? -ne 0 ]; then
        echo "PostgreSQL: Failed to initialize database cluster"
        exit 1
    fi
    
    echo "PostgreSQL: Database cluster initialized successfully"
    
    # Configure PostgreSQL to listen on all addresses and port 5432
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "port = 5432" >> "$PGDATA/postgresql.conf"
    
    # Configure authentication
    echo "host all all all md5" >> "$PGDATA/pg_hba.conf"
    
    echo "PostgreSQL: Configuration updated"
    
    # Start PostgreSQL temporarily to create user and database
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "$PGDATA" \
        -l "$PGDATA/logfile" \
        -w start
    if [ $? -ne 0 ]; then
        echo "PostgreSQL: Failed to start temporary server"
        exit 1
    fi
    
    echo "PostgreSQL: Temporary server started"
    
    # Create user and database if specified
    if [ "$POSTGRES_USER" != "postgres" ]; then
        echo "PostgreSQL: Creating user '$POSTGRES_USER'"
        sudo -u postgres psql -c "CREATE USER \"$POSTGRES_USER\" WITH SUPERUSER PASSWORD '$POSTGRES_PASSWORD';"
        if [ $? -ne 0 ]; then
            echo "PostgreSQL: Failed to create user"
            exit 1
        fi
    else
        # Set password for postgres user
        echo "PostgreSQL: Setting password for postgres user"
        sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"
        if [ $? -ne 0 ]; then
            echo "PostgreSQL: Failed to set password for postgres user"
            exit 1
        fi
    fi
    
    if [ "$POSTGRES_DB" != "postgres" ]; then
        echo "PostgreSQL: Creating database '$POSTGRES_DB'"
        sudo -u postgres createdb "$POSTGRES_DB"
        if [ $? -ne 0 ]; then
            echo "PostgreSQL: Failed to create database"
            exit 1
        fi
        
        # Set ownership if user is not postgres
        if [ "$POSTGRES_USER" != "postgres" ]; then
            sudo -u postgres psql -c "ALTER DATABASE \"$POSTGRES_DB\" OWNER TO \"$POSTGRES_USER\";"
            if [ $? -ne 0 ]; then
                echo "PostgreSQL: Failed to set database owner"
                exit 1
            fi
        fi
    fi
    
    # Execute initialization SQL files
    if [ -d /docker-entrypoint-initdb.d ]; then
        echo "PostgreSQL: Executing initialization scripts..."
        for f in /docker-entrypoint-initdb.d/*.sql; do
            if [ -f "$f" ]; then
                echo "PostgreSQL: Running $f"
                sudo -u postgres psql -d "$POSTGRES_DB" -f "$f"
                if [ $? -ne 0 ]; then
                    echo "PostgreSQL: Failed to execute $f"
                    exit 1
                fi
            fi
        done
    fi
    
    # Stop the temporary server
    echo "PostgreSQL: Stopping temporary server"
    sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "$PGDATA" \
        -m fast \
        -w stop
    if [ $? -ne 0 ]; then
        echo "PostgreSQL: Failed to stop temporary server"
        exit 1
    fi
    
    echo "PostgreSQL: Initialization completed successfully"
else
    echo "PostgreSQL: Database already initialized"
fi

echo "PostgreSQL: Initialization process completed"
exit 0
