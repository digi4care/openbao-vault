#!/bin/bash
# Script for rotating tokens and implementing token lifecycle management in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Function to show help
show_help() {
  echo "Usage: $0 [-u USERNAME] [-r ROLE_NAME] [-t TTL] [-m MAX_TTL] [-p POLICY_NAME] [-n NUMBER] [-f]"
  echo
  echo "Rotate tokens and implement token lifecycle management"
  echo
  echo "Options:"
  echo "  -u USERNAME    Username to create token for (using userpass auth)"
  echo "  -r ROLE_NAME   Role name to create token for (using approle auth)"
  echo "  -t TTL         Token time-to-live (default: 1h)"
  echo "  -m MAX_TTL     Maximum token TTL (default: 24h)"
  echo "  -p POLICY_NAME Policy to attach to token (default: default)"
  echo "  -n NUMBER      Number of tokens to create (default: 1)"
  echo "  -f            Force token creation without confirmation"
  echo "  -? | --help    Show this help message"
  echo
  echo "Example:"
  echo "  $0 -u admin.user -t 2h -m 24h -p admin"
  echo "  $0 -r payment-service -t 1h -p payment-service-policy"
  exit 1
}

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
USERNAME=""
ROLE_NAME=""
TTL="1h"
MAX_TTL="24h"
POLICY_NAME="default"
NUMBER=1
FORCE=false

# Parse command line arguments
while getopts "u:r:t:m:p:n:f?" opt; do
  case $opt in
    u)
      USERNAME=$OPTARG
      ;;
    r)
      ROLE_NAME=$OPTARG
      ;;
    t)
      TTL=$OPTARG
      ;;
    m)
      MAX_TTL=$OPTARG
      ;;
    p)
      POLICY_NAME=$OPTARG
      ;;
    n)
      NUMBER=$OPTARG
      ;;
    f)
      FORCE=true
      ;;
    \?|*)
      show_help
      ;;
  esac
done

# Check parameters
if [ -z "$USERNAME" ] && [ -z "$ROLE_NAME" ]; then
  echo "ERROR: Either username or role name is required"
  show_help
fi

if [ ! -z "$USERNAME" ] && [ ! -z "$ROLE_NAME" ]; then
  echo "ERROR: Cannot specify both username and role name"
  show_help
fi

# Export environment variables
export VAULT_ADDR
export VAULT_TOKEN

echo "OpenBAO Token Rotation"
echo "================================================================================"

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

# Create token role for lifecycle management if it doesn't exist
echo -e "\nChecking if token role exists..."
TOKEN_ROLE_NAME="${POLICY_NAME}-role"

if ! vault read auth/token/roles/$TOKEN_ROLE_NAME > /dev/null 2>&1; then
  echo "Creating token role: $TOKEN_ROLE_NAME"
  vault write auth/token/roles/$TOKEN_ROLE_NAME \
    allowed_policies=$POLICY_NAME \
    period=$TTL \
    renewable=true \
    explicit_max_ttl=$MAX_TTL
  echo "Token role created."
else
  echo "Updating token role: $TOKEN_ROLE_NAME"
  vault write auth/token/roles/$TOKEN_ROLE_NAME \
    allowed_policies=$POLICY_NAME \
    period=$TTL \
    renewable=true \
    explicit_max_ttl=$MAX_TTL
  echo "Token role updated."
fi

# Get authentication token
TOKEN=""
if [ ! -z "$USERNAME" ]; then
  echo -e "\nAuthenticating as user: $USERNAME"

  # Prompt for password
  read -s -p "Enter password for $USERNAME: " PASSWORD
  echo

  # Login with userpass
  LOGIN_RESPONSE=$(vault write -format=json auth/userpass/login/$USERNAME password="$PASSWORD")
  TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.auth.client_token')

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Authentication failed for user $USERNAME"
    exit 1
  fi

  echo "Authentication successful."

elif [ ! -z "$ROLE_NAME" ]; then
  echo -e "\nGetting AppRole credentials for role: $ROLE_NAME"

  # Get role-id and secret-id
  ROLE_ID=$(vault read -format=json auth/approle/role/$ROLE_NAME/role-id | jq -r '.data.role_id')
  SECRET_ID=$(vault write -format=json -f auth/approle/role/$ROLE_NAME/secret-id | jq -r '.data.secret_id')

  if [ -z "$ROLE_ID" ] || [ "$ROLE_ID" = "null" ] || [ -z "$SECRET_ID" ] || [ "$SECRET_ID" = "null" ]; then
    echo "ERROR: Could not get AppRole credentials for role $ROLE_NAME"
    exit 1
  fi

  # Login with approle
  LOGIN_RESPONSE=$(vault write -format=json auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID)
  TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.auth.client_token')

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Authentication failed for role $ROLE_NAME"
    exit 1
  fi

  echo "Authentication successful."
fi

# Create new tokens
echo -e "\nCreating $NUMBER new token(s) with TTL: $TTL and max TTL: $MAX_TTL"

if [ "$FORCE" != true ]; then
  read -p "Continue? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Save the current token
CURRENT_TOKEN=$VAULT_TOKEN

# Use the authenticated token
export VAULT_TOKEN=$TOKEN

# Create tokens
for i in $(seq 1 $NUMBER); do
  echo -e "\nCreating token #$i..."

  # Create token using the role
  TOKEN_RESPONSE=$(vault token create -format=json -role=$TOKEN_ROLE_NAME)
  NEW_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.auth.client_token')
  TOKEN_ACCESSOR=$(echo $TOKEN_RESPONSE | jq -r '.auth.accessor')

  echo "Token created successfully!"
  echo "Token: $NEW_TOKEN"
  echo "Accessor: $TOKEN_ACCESSOR"
  echo "TTL: $TTL"
  echo "Max TTL: $MAX_TTL"
  echo "Policies: $POLICY_NAME"

  # Save token to file
  TOKEN_FILE="token_${POLICY_NAME}_$(date +%Y%m%d_%H%M%S)_$i.txt"
  echo "Token: $NEW_TOKEN" > $TOKEN_FILE
  echo "Accessor: $TOKEN_ACCESSOR" >> $TOKEN_FILE
  echo "Created: $(date)" >> $TOKEN_FILE
  echo "TTL: $TTL" >> $TOKEN_FILE
  echo "Max TTL: $MAX_TTL" >> $TOKEN_FILE
  echo "Policies: $POLICY_NAME" >> $TOKEN_FILE

  echo "Token saved to file: $TOKEN_FILE"
done

# Restore the original token
export VAULT_TOKEN=$CURRENT_TOKEN

echo -e "\n================================================================================"
echo "Token rotation complete!"
echo "================================================================================"
echo "Remember to securely store the new tokens and implement automatic rotation"
echo "For production use, consider using a secrets manager or CI/CD pipeline for rotation"
echo "================================================================================"
