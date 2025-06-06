#!/command/with-contenv bash

# Run MinIO in foreground
exec sudo -u minio-user minio server "${MINIO_DATA_DIR}" --console-address ":${MINIO_CONSOLE_PORT:-9090}"
