#!/bin/bash
# Script to check the status of OpenBAO
# Especially useful in production environment, in development environment OpenBAO is ready for use immediately
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}

# In production, you must use the root token you get when initializing
# In development, you need to get the root token from the container logs
if [ -z "$VAULT_TOKEN" ]; then
  echo "WARNING: No VAULT_TOKEN provided."
  echo "- For development: retrieve the root token with 'docker logs openbao-dev | grep "Root Token"'"
  echo "  and then use 'export VAULT_TOKEN=<token-from-logs>'"
  echo "- For production: use the root token you received from 'vault operator init'"
  exit 1
fi

echo "OpenBAO status check script"
echo "============================"
echo "Connecting to OpenBAO at $VAULT_ADDR"

# Export environment variables
export VAULT_ADDR
export VAULT_TOKEN

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

echo "OpenBAO is accessible. Status:"
vault status | grep "Seal Type\|Version"

echo -e "\n================================================"
echo "OpenBAO is accessible and ready for use!"
echo "================================================"
echo "You can now run the create_namespace.sh script to"
echo "prepare the organization namespace and authentication:"
echo "./scripts/create_namespace.sh --organization <organization-name>"
echo "================================================"
