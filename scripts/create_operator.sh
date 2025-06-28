#!/bin/bash
# Script for creating a service operator in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Help function
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "This script creates an operator for a specific service within an organization namespace."
  echo "This operator can only manage the secrets of that specific service."
  echo ""
  echo "Options:"
  echo "  -o, --organization NAME  Organization name (required)"
  echo "  -s, --service ID         Service ID (required)"
  echo "  -u, --username NAME      Operator username (required)"
  echo "  -p, --password PASS      Operator password (optional, will be prompted if not provided)"
  echo "  -h, --help               Show this help"
  echo ""
  echo "Example: $0 --organization acme-corp --service payment --username payment-operator"
  exit 1
}

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
ORGANIZATION=""
SERVICE_ID=""
USERNAME=""
PASSWORD=""

# In production, use an admin token, not the root token
if [ -z "$VAULT_TOKEN" ]; then
  echo "WARNING: No VAULT_TOKEN provided."
  echo "Use an admin token or the root token (only for setup)."
  exit 1
fi

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -o|--organization)
      ORGANIZATION="$2"
      shift
      shift
      ;;
    -s|--service)
      SERVICE_ID="$2"
      shift
      shift
      ;;
    -u|--username)
      USERNAME="$2"
      shift
      shift
      ;;
    -p|--password)
      PASSWORD="$2"
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

# Check if required parameters are provided
if [ -z "$ORGANIZATION" ]; then
  echo "ERROR: Organization is required"
  show_help
fi

if [ -z "$SERVICE_ID" ]; then
  echo "ERROR: Service ID is required"
  show_help
fi

if [ -z "$USERNAME" ]; then
  echo "ERROR: Username is required"
  show_help
fi

# Prompt for password if not provided
if [ -z "$PASSWORD" ]; then
  echo -n "Enter password for operator $USERNAME: "
  read -s PASSWORD
  echo ""

  echo -n "Confirm password: "
  read -s PASSWORD_CONFIRM
  echo ""

  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "ERROR: Passwords do not match"
    exit 1
  fi
fi

# Export environment variables
export VAULT_ADDR
export VAULT_TOKEN

echo "Creating OpenBAO service operator: $USERNAME for service $SERVICE_ID in organization $ORGANIZATION"
echo "================================================================================"

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

# Check if the organization namespace exists
echo -e "\nChecking if organization $ORGANIZATION exists..."
if ! vault namespace list | grep -q "^$ORGANIZATION/"; then
  echo "ERROR: Organization $ORGANIZATION does not exist"
  echo "First create the organization with create_namespace.sh"
  exit 1
fi

# Select the organization namespace
export VAULT_NAMESPACE=$ORGANIZATION
echo "Organization selected: $VAULT_NAMESPACE"

# Enable userpass authentication if not already enabled
echo -e "\nEnabling userpass authentication in organization $ORGANIZATION..."
if ! vault auth list | grep -q "^userpass/"; then
  vault auth enable userpass
  echo "Userpass authentication enabled."
else
  echo "Userpass authentication is already enabled."
fi

# Create operator policy
echo -e "\nCreating operator policy for service $SERVICE_ID..."
POLICY_NAME="${SERVICE_ID}-operator"

cat > /tmp/${POLICY_NAME}.hcl << EOF
# Operator policy for service $SERVICE_ID
# Provides full access to the secrets of this service

# Read/write access to service secrets
path "services/$SERVICE_ID/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read-only access to services list
path "services/" {
  capabilities = ["list"]
}

# Read-only access to own service
path "services/$SERVICE_ID" {
  capabilities = ["list", "read"]
}
EOF

vault policy write $POLICY_NAME /tmp/${POLICY_NAME}.hcl
echo "Policy '$POLICY_NAME' created."

# Create operator user
echo -e "\nCreating operator user..."
vault write auth/userpass/users/$USERNAME \
  password="$PASSWORD" \
  policies=$POLICY_NAME

echo -e "\n================================================================================"
echo "Service operator successfully created!"
echo "================================================================================"
echo "Organization: $ORGANIZATION"
echo "Service: $SERVICE_ID"
echo "Username: $USERNAME"
echo "Policy: $POLICY_NAME"
echo "================================================================================"
echo -e "\nThe operator can log in with:"
echo "export VAULT_NAMESPACE=$ORGANIZATION"
echo "vault login -method=userpass username=$USERNAME"
echo "================================================================================"
