#!/bin/bash
# Script for creating a global admin user in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Help function
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "This script creates a global admin user who can manage all organization namespaces."
  echo "This admin replaces the root token for daily use."
  echo ""
  echo "Options:"
  echo "  -u, --username NAME    Admin username (required)"
  echo "  -p, --password PASS    Admin password (optional, will be prompted if not provided)"
  echo "  -h, --help             Show this help"
  echo ""
  echo "Example: $0 --username admin"
  exit 1
}

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
USERNAME=""
PASSWORD=""

# In production, use the root token you get when initializing
# In development, you can use the default root token
if [ -z "$VAULT_TOKEN" ]; then
  echo "WARNING: No VAULT_TOKEN provided."
  echo "- For development: use 'export VAULT_TOKEN=root-token-dev'"
  echo "- For production: use the root token you received from 'vault operator init'"
  exit 1
fi

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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

# Check if USERNAME is provided
if [ -z "$USERNAME" ]; then
  echo "ERROR: Username is required"
  show_help
fi

# Prompt for password if not provided
if [ -z "$PASSWORD" ]; then
  echo -n "Enter password for user $USERNAME: "
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

echo "Creating OpenBAO global admin: $USERNAME"
echo "================================================"

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

# Enable userpass authentication if not already enabled
echo -e "\nEnabling userpass authentication..."
if ! vault auth list | grep -q "^userpass/"; then
  vault auth enable userpass
  echo "Userpass authentication enabled."
else
  echo "Userpass authentication is already enabled."
fi

# Create admin policy
echo -e "\nCreating admin policy..."
cat > /tmp/admin-policy.hcl << EOF
# Admin policy for global administrator
# Provides full access to the system, except for root-only operations

# System management
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Organization namespace management
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Auth methods management
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Secrets engines management
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Policies management
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Access to all secrets
path "+/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

vault policy write admin /tmp/admin-policy.hcl
echo "Admin policy created."

# Create admin user
echo -e "\nCreating admin user..."
vault write auth/userpass/users/$USERNAME \
  password="$PASSWORD" \
  policies=admin

echo -e "\n================================================"
echo "Global admin user successfully created!"
echo "================================================"
echo "Username: $USERNAME"
echo "Policy: admin"
echo "================================================"
echo -e "\nYou can now log in with:"
echo "vault login -method=userpass username=$USERNAME"
echo -e "\nIt is recommended to revoke the root token after testing this admin user:"
echo "vault token revoke -self"
echo "================================================"
