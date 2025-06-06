#!/command/with-contenv bash

# Run PostgreSQL in foreground
exec sudo -u postgres /usr/lib/postgresql/15/bin/postgres -D "$PGDATA"
