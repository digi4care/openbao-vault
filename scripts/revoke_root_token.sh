#!/bin/bash
# Script to revoke the current root token after creating a global admin
# This improves security by removing the root token from circulation
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

# Show help information
show_help() {
  echo "Revoke OpenBAO Root Token"
  echo "=========================="
  echo "This script revokes the current root token."
  echo "IMPORTANT: Make sure you have created a global admin user before revoking the root token!"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -f, --force    Skip confirmation prompt"
  echo
  echo "Example:"
  echo "  $0"
  echo "  $0 --force"
}

# Process command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    *)
      echo "Unknown option: $key"
      show_help
      exit 1
      ;;
  esac
done

# Check if OpenBAO is accessible
echo "Revoking OpenBAO root token"
echo "=========================="
echo "Checking if OpenBAO is accessible..."

if ! vault status &>/dev/null; then
  echo "Error: Cannot connect to OpenBAO. Please check your connection and VAULT_ADDR."
  exit 1
fi

# Check if the current token is a root token
TOKEN_INFO=$(vault token lookup -format=json 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Error: Failed to lookup token information. Make sure VAULT_TOKEN is set correctly."
  exit 1
fi

IS_ROOT=$(echo "$TOKEN_INFO" | jq -r '.data.policies | contains(["root"])')
if [ "$IS_ROOT" != "true" ]; then
  echo "Error: The current token is not a root token. Only root tokens can be revoked with this script."
  exit 1
fi

# Confirm revocation unless force flag is set
if [ "$FORCE" != "true" ]; then
  echo
  echo "WARNING: You are about to revoke the root token. This action cannot be undone."
  echo "Make sure you have created a global admin user with the create_global_admin.sh script."
  echo "Without a root token or admin user, you will lose access to manage OpenBAO."
  echo
  read -p "Are you sure you want to continue? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Revoke the token
echo "Revoking root token..."
if vault token revoke -self; then
  echo
  echo "================================================"
  echo "Root token successfully revoked!"
  echo "================================================"
  echo "The root token has been invalidated and can no longer be used."
  echo "Use your global admin user to manage OpenBAO from now on."
  echo "================================================"
else
  echo "Error: Failed to revoke the root token."
  exit 1
fi
