import time
import os
import sys

print("Hello from Python application!")
print(f"Python version: {sys.version}")
print(f"POSTGRES_USER: {os.getenv('POSTGRES_USER', 'not set')}")
print(f"POSTGRES_DB: {os.getenv('POSTGRES_DB', 'not set')}")
print(f"MINIO_ROOT_USER: {os.getenv('MINIO_ROOT_USER', 'not set')}")
print(f"MINIO_DATA_DIR: {os.getenv('MINIO_DATA_DIR', 'not set')}")
print(f"MINIO_PORT: {os.getenv('MINIO_PORT', 'not set')}")


# Keep the app running to simulate a service
try:
    count = 0
    while True:
        count += 1
        print(f"Python app is running... (iteration {count})")
        # Example: You could add logic here to connect to PostgreSQL or Minio
        time.sleep(60)
except KeyboardInterrupt:
    print("Python app stopping.")
