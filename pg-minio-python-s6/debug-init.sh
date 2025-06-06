#!/bin/bash
echo "Debug init script starting..."

# Try to reproduce the issue
if [ -f /run/s6/container_environment ]; then
    echo "Found container environment file"
    export $(cat /run/s6/container_environment | xargs) 2>/dev/null || echo "Failed to export env vars"
else
    echo "No container environment file found"
fi

echo "Debug init script complete."
