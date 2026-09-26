#!/bin/bash
# unRAID User Script: Run "At Startup of Array" and set to "Run in background"

DB_CONTAINER="postgresql17"
NEXTCLOUD_CONTAINER="nextcloud-app"
PAPERLESS_CONTAINER="paperless-stack-webserver"

NETWORKS=("paperless-net" "nextcloud-net")

connect_networks() {
  sleep 3

  # 1. Sicherstellen, dass die Netzwerke existieren
  for NET in "${NETWORKS[@]}"; do
    if ! docker network inspect "$NET" >/dev/null 2>&1; then
      echo "Creating missing network: $NET"
      docker network create "$NET"
    fi
  done

  # 2. Postgres in BEIDE Netze hängen
  for NET in "${NETWORKS[@]}"; do
    if docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
      if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$DB_CONTAINER" 2>/dev/null | grep -q "$NET"; then
        echo "Connecting $DB_CONTAINER to $NET..."
        docker network connect "$NET" "$DB_CONTAINER"
      fi
    fi
  done

  # 3. Nextcloud gezielt in das nextcloud-net hängen
  if docker inspect "$NEXTCLOUD_CONTAINER" >/dev/null 2>&1; then
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$NEXTCLOUD_CONTAINER" 2>/dev/null | grep -q "nextcloud-net"; then
      echo "Connecting $NEXTCLOUD_CONTAINER to nextcloud-net..."
      docker network connect "nextcloud-net" "$NEXTCLOUD_CONTAINER"
    fi
  fi

  # 4. Paperless gezielt in das paperless-net hängen
  if docker inspect "$PAPERLESS_CONTAINER" >/dev/null 2>&1; then
    if ! docker inspect -f '{{json .NetworkSettings.Networks}}' "$PAPERLESS_CONTAINER" 2>/dev/null | grep -q "paperless-net"; then
      echo "Connecting $PAPERLESS_CONTAINER to paperless-net..."
      docker network connect "paperless-net" "$PAPERLESS_CONTAINER"
    fi
  fi
}

# 1. Initialer Lauf beim unRAID Start
sleep 30
connect_networks

# 2. Event-Schleife: Reagiert auf Starts von Postgres, Nextcloud ODER Paperless
echo "Listening to Docker start events..."
docker events --filter event=start | while read -r event; do
  # Prüfen, ob das Event von einem der drei Container kam
  if echo "$event" | grep -qE "container=($DB_CONTAINER|$NEXTCLOUD_CONTAINER|$PAPERLESS_CONTAINER)"; then
    echo "Event registered: Relevant container started/recreated!"
    connect_networks
  fi
done
