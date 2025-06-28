#!/bin/bash
# Script for enabling MFA for a user in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Function to show help
show_help() {
  echo "Usage: $0 -u USERNAME [-t MFA_TYPE] [-d DUO_IKEY] [-s DUO_SKEY] [-h DUO_HOST] [-f TOTP_ISSUER]"
  echo
  echo "Enable Multi-Factor Authentication (MFA) for a user"
  echo
  echo "Options:"
  echo "  -u USERNAME    Username to enable MFA for"
  echo "  -t MFA_TYPE    Type of MFA to enable (duo or totp, default: totp)"
  echo "  -d DUO_IKEY    Duo integration key (required for duo)"
  echo "  -s DUO_SKEY    Duo secret key (required for duo)"
  echo "  -h DUO_HOST    Duo API hostname (required for duo)"
  echo "  -f TOTP_ISSUER TOTP issuer name (optional for totp, default: OpenBAO)"
  echo "  -? | --help    Show this help message"
  echo
  echo "Example:"
  echo "  $0 -u admin.user -t totp"
  echo "  $0 -u admin.user -t duo -d DIXXXXXXXXXXXXXXXXXX -s secret -h api-XXXXXXXX.duosecurity.com"
  exit 1
}

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
USERNAME=""
MFA_TYPE="totp"
DUO_IKEY=""
DUO_SKEY=""
DUO_HOST=""
TOTP_ISSUER="OpenBAO"

# Parse command line arguments
while getopts "u:t:d:s:h:f:?" opt; do
  case $opt in
    u)
      USERNAME=$OPTARG
      ;;
    t)
      MFA_TYPE=$OPTARG
      ;;
    d)
      DUO_IKEY=$OPTARG
      ;;
    s)
      DUO_SKEY=$OPTARG
      ;;
    h)
      DUO_HOST=$OPTARG
      ;;
    f)
      TOTP_ISSUER=$OPTARG
      ;;
    \?|*)
      show_help
      ;;
  esac
done

# Check required parameters
if [ -z "$USERNAME" ]; then
  echo "ERROR: Username is required"
  show_help
fi

if [ "$MFA_TYPE" != "totp" ] && [ "$MFA_TYPE" != "duo" ]; then
  echo "ERROR: MFA type must be 'totp' or 'duo'"
  show_help
fi

if [ "$MFA_TYPE" = "duo" ]; then
  if [ -z "$DUO_IKEY" ] || [ -z "$DUO_SKEY" ] || [ -z "$DUO_HOST" ]; then
    echo "ERROR: Duo integration key, secret key, and API hostname are required for Duo MFA"
    show_help
  fi
fi

# Export environment variables
export VAULT_ADDR
export VAULT_TOKEN

echo "Enabling MFA for user: $USERNAME"
echo "================================================================================"

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

# Check if the user exists
echo -e "\nChecking if user $USERNAME exists..."
if ! vault read auth/userpass/users/$USERNAME > /dev/null 2>&1; then
  echo "ERROR: User $USERNAME does not exist"
  exit 1
fi

# Get the userpass mount accessor
echo -e "\nGetting userpass mount accessor..."
USERPASS_ACCESSOR=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
if [ -z "$USERPASS_ACCESSOR" ]; then
  echo "ERROR: Could not get userpass mount accessor"
  exit 1
fi

# Enable MFA auth method if not already enabled
echo -e "\nEnabling MFA auth method..."
if ! vault auth list | grep -q "^mfa/"; then
  vault auth enable mfa
  echo "MFA auth method enabled."
else
  echo "MFA auth method is already enabled."
fi

# Configure MFA for the user
if [ "$MFA_TYPE" = "totp" ]; then
  echo -e "\nConfiguring TOTP MFA for user $USERNAME..."

  # Create TOTP method
  METHOD_ID="totp_$USERNAME"
  vault write auth/mfa/method/totp/$METHOD_ID \
    issuer=$TOTP_ISSUER \
    period=30 \
    key_size=30 \
    qr_size=200 \
    algorithm=SHA1 \
    digits=6

  # Generate TOTP key for the user
  TOTP_RESULT=$(vault write -format=json auth/mfa/method/totp/$METHOD_ID/generate \
    entity_id=$(vault read -format=json identity/lookup/entity \
      name=$USERNAME | jq -r '.data.id'))

  # Extract and display TOTP information
  TOTP_URL=$(echo $TOTP_RESULT | jq -r '.data.url')
  TOTP_BASE64=$(echo $TOTP_RESULT | jq -r '.data.barcode')

  echo -e "\n================================================================================"
  echo "TOTP MFA configured successfully for user $USERNAME!"
  echo "================================================================================"
  echo "TOTP URL: $TOTP_URL"
  echo -e "\nScan this QR code with your authenticator app:"
  echo $TOTP_BASE64 | base64 -d
  echo -e "\nIMPORTANT: Save this information securely. It will not be shown again."
  echo "================================================================================"

  # Configure MFA enforcement
  echo -e "\nConfiguring MFA enforcement for user $USERNAME..."
  vault write auth/mfa/login-enforcement/admins \
    name="Admin MFA Enforcement" \
    mfa_method_ids=$METHOD_ID \
    identity_entity_ids=$(vault read -format=json identity/lookup/entity \
      name=$USERNAME | jq -r '.data.id')

  echo -e "\nMFA enforcement configured. User $USERNAME will now be required to use MFA."

elif [ "$MFA_TYPE" = "duo" ]; then
  echo -e "\nConfiguring Duo MFA for user $USERNAME..."

  # Create Duo method
  METHOD_ID="duo_$USERNAME"
  vault write auth/mfa/method/duo/$METHOD_ID \
    mount_accessor=$USERPASS_ACCESSOR \
    integration_key=$DUO_IKEY \
    secret_key=$DUO_SKEY \
    api_hostname=$DUO_HOST

  # Configure MFA enforcement
  echo -e "\nConfiguring MFA enforcement for user $USERNAME..."
  vault write auth/mfa/login-enforcement/admins \
    name="Admin MFA Enforcement" \
    mfa_method_ids=$METHOD_ID \
    identity_entity_ids=$(vault read -format=json identity/lookup/entity \
      name=$USERNAME | jq -r '.data.id')

  echo -e "\n================================================================================"
  echo "Duo MFA configured successfully for user $USERNAME!"
  echo "================================================================================"
  echo "The user will now be required to authenticate with Duo MFA."
  echo "================================================================================"
fi

echo -e "\nMFA setup complete!"
