FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql postgresql-contrib && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["which", "postgres"]
