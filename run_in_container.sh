#!/bin/bash
# Eenvoudig wrapper script om OpenBAO scripts in de Docker container uit te voeren
# Auteur: Chris Engelhard
# Datum: 2025-06-28

set -e

# Check if the script name is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <script_name> [arguments...]"
  echo "Example: $0 create_namespace.sh --namespace example"
  exit 1
fi

SCRIPT_NAME=$1
shift  # Remove the script name from the arguments

# Check if the container is running
if ! docker ps | grep -q openbao-dev; then
  echo "Error: OpenBAO container is not running."
  echo "Please start it with: docker-compose -f docker-compose.dev.yml up -d"
  exit 1
fi

# Get the latest root token from logs if VAULT_TOKEN is not set
if [ -z "$VAULT_TOKEN" ]; then
  echo "VAULT_TOKEN is not set. Attempting to get the latest root token from container logs..."
  ROOT_TOKEN=$(docker logs openbao-dev 2>&1 | grep "Root Token:" | tail -1 | awk '{print $NF}')

  if [ -z "$ROOT_TOKEN" ]; then
    echo "Could not find Root Token in container logs."
    echo "Please set VAULT_TOKEN manually: export VAULT_TOKEN=<your-token>"
    exit 1
  else
    echo "Found latest Root Token: $ROOT_TOKEN"
    VAULT_TOKEN=$ROOT_TOKEN
  fi
fi

echo "Executing $SCRIPT_NAME in OpenBAO container..."

# Zorg ervoor dat het script uitvoerbaar is
docker exec openbao-dev chmod +x /opt/bin/$SCRIPT_NAME

echo "Command: docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=$VAULT_TOKEN openbao-dev sh -c \"cd /opt/bin && sh $SCRIPT_NAME $*\""
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=$VAULT_TOKEN openbao-dev sh -c "cd /opt/bin && sh $SCRIPT_NAME $*"
