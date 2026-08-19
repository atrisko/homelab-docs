#!/bin/bash
# unRAID User Script: Run "At Startup of Array" and set to "Run in background"

CONTAINER_NAME="postgresql17"
NETWORKS=("paperless-net" "nextcloud-net")

connect_networks() {
  for NET in "${NETWORKS[@]}"; do
    # 1. Check if network exists, create if missing (safely without substring grep)
    if ! docker network inspect "$NET" >/dev/null 2>&1; then
      echo "Creating missing network: $NET"
      docker network create "$NET"
    fi
    
    # 2. Check if container is connected (native Docker formatting, no 'jq' required)
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "$NET"; then
      echo "Connecting $CONTAINER_NAME to $NET..."
      docker network connect "$NET" "$CONTAINER_NAME"
    fi
  done
}

# 1. Initial connection on array boot (allow Docker daemon to fully initialize)
sleep 15
connect_networks

# 2. Infinite event-loop: Listen to Postgres startup/upgrade events live
echo "Listening to Docker start events for $CONTAINER_NAME..."
docker events --filter container="$CONTAINER_NAME" --filter event=start | while read -r event; do
  echo "Event registered: Postgres container started/recreated!"
  sleep 3 # Give Docker a moment to finish internal IP allocations
  connect_networks
done