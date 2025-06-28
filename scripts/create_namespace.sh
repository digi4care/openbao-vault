#!/bin/sh
# Script for preparing an organization namespace in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Help function
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -o, --organization NAME  Organization name for the namespace (default: acme)"
  echo "  -p, --path PATH          Path for KV secrets engine (default: services)"
  echo "  -r, --role NAME          AppRole name (default: org-role)"
  echo "  -t, --ttl TIME           Token TTL (default: 1h)"
  echo "  -h, --help               Show this help"
  echo ""
  echo "Example: $0 --organization acme-corp --path services --role api-access"
  exit 0
}

# Configuration with default values
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
ORGANIZATION="acme"
SECRETS_PATH="services"
ROLE_NAME=""
TOKEN_TTL="1h"

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -o|--organization)
      ORGANIZATION="$2"
      shift
      shift
      ;;
    -p|--path)
      SECRETS_PATH="$2"
      shift
      shift
      ;;
    -r|--role)
      ROLE_NAME="$2"
      shift
      shift
      ;;
    -t|--ttl)
      TOKEN_TTL="$2"
      shift
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# If no role name is provided, use org-role
if [ -z "$ROLE_NAME" ]; then
  ROLE_NAME="${ORGANIZATION}-role"
fi

# Policy name derived from organization
POLICY_NAME="${ORGANIZATION}-read"

# In production, use the root token you get when initializing
# In development, you can use the default root token
if [ -z "$VAULT_TOKEN" ]; then
  echo "WARNING: No VAULT_TOKEN provided."
  echo "- For development: use 'export VAULT_TOKEN=root-token-dev'"
  echo "- For production: use the root token you received from 'vault operator init'"
  exit 1
fi

echo "Preparing OpenBAO organization '$ORGANIZATION'"
echo "=================================="
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

# Create organization namespace
echo -e "\nCreating organization namespace '$ORGANIZATION'..."
if vault namespace list | grep -q "^$ORGANIZATION/"; then
  echo "Organization namespace '$ORGANIZATION' already exists."
else
  vault namespace create $ORGANIZATION
  echo "Organization namespace '$ORGANIZATION' created."
fi

# Select the organization namespace for subsequent commands
export VAULT_NAMESPACE=$ORGANIZATION
echo "Organization namespace selected: $VAULT_NAMESPACE"

# Enable KV secrets engine
echo -e "\nEnabling KV secrets engine at path '$SECRETS_PATH'..."
if vault secrets list | grep -q "^$SECRETS_PATH/"; then
  echo "KV secrets engine at path '$SECRETS_PATH' already exists."
else
  vault secrets enable -path=$SECRETS_PATH kv-v2
  echo "KV secrets engine enabled at path '$SECRETS_PATH'."
fi

# Enable AppRole authentication
echo -e "\nEnabling AppRole authentication..."
if vault auth list | grep -q "^approle/"; then
  echo "AppRole authentication is already enabled."
else
  vault auth enable approle
  echo "AppRole authentication enabled."
fi

# Create policy
echo -e "\nCreating policy for $ORGANIZATION..."
cat > /tmp/${POLICY_NAME}.hcl << EOF
# Read access to all secrets in $SECRETS_PATH
path "$SECRETS_PATH/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write $POLICY_NAME /tmp/${POLICY_NAME}.hcl
echo "Policy '$POLICY_NAME' created."

# Configure AppRole
echo -e "\nConfiguring AppRole for $ORGANIZATION..."
vault write auth/approle/role/$ROLE_NAME \
    token_ttl=$TOKEN_TTL \
    token_max_ttl=24h \
    policies=$POLICY_NAME
echo "AppRole '$ROLE_NAME' configured."

# Retrieve credentials
echo -e "\nRetrieving credentials for $ORGANIZATION..."
ROLE_ID=$(vault read -format=json auth/approle/role/$ROLE_NAME/role-id | jq -r .data.role_id)
SECRET_ID=$(vault write -f -format=json auth/approle/role/$ROLE_NAME/secret-id | jq -r .data.secret_id)

echo -e "\n================================================"
echo "Organization '$ORGANIZATION' successfully configured!"
echo "================================================"
echo "Save these credentials for use:"
echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo "Organization: $ORGANIZATION"
echo "Role: $ROLE_NAME"
echo "Policy: $POLICY_NAME"
echo "Secrets Path: $SECRETS_PATH"
echo "================================================"
echo -e "\nUse the add_service.sh script to add services to this organization."
