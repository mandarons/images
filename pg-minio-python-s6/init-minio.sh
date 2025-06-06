#!/command/with-contenv bash
# This script is run by s6-overlay during container startup

echo "Starting MinIO..."

# Ensure the data directory exists and has correct permissions
mkdir -p "${MINIO_DATA_DIR}"
chown -R minio-user:minio-user "${MINIO_DATA_DIR}"

# Start MinIO in the background
echo "Starting MinIO server..."
sudo -u minio-user minio server "${MINIO_DATA_DIR}" --console-address ":${MINIO_CONSOLE_PORT:-9090}" &

# Wait for the background process to start
sleep 5

echo "Waiting for MinIO to be ready..."
# Add a loop to check if MinIO is ready, e.g., by checking its health endpoint
for i in {1..30}; do
    if curl -s http://localhost:${MINIO_PORT:-9000}/minio/health/live > /dev/null 2>&1; then
        echo "MinIO is up and running."
        break
    fi
    echo "MinIO is unavailable - sleeping (attempt $i/30)"
    sleep 2
done

if [ $i -eq 30 ]; then
    echo "MinIO failed to start after 60 seconds"
    exit 1
fi

echo "MinIO setup complete."
