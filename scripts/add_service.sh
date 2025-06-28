#!/bin/sh
# Script for adding a new service in OpenBAO
# Author: Chris Engelhard <chris@chrisengelhard.nl>
# Date: 2025-06-28

set -e

# Function to display help
show_help() {
  echo "Usage: $0 -o ORGANIZATION -s SERVICE_ID [-k KEY1=VALUE1] [-k KEY2=VALUE2] ..."
  echo
  echo "Options:"
  echo "  -o ORGANIZATION  Required: Organization in which the service will be added"
  echo "  -s SERVICE_ID    Required: ID of the service (e.g., 'payment')"
  echo "  -k KEY=VALUE     Optional: API key in format NAME=VALUE (multiple -k options possible)"
  echo "  -f FILE          Optional: Path to JSON file with API keys"
  echo "  -h               Show this help"
  echo
  echo "Examples:"
  echo "  $0 -o acme-corp -s payment -k stripe=sk_test_12345 -k paypal=client_id_abcdef"
  echo "  $0 -o acme-corp -s notification -f keys.json"
  exit 1
}

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"root-token-dev"}
ORGANIZATION=""
SERVICE_ID=""
API_KEYS=""
JSON_FILE=""

# Process command line arguments
while getopts "o:s:k:f:h" opt; do
  case $opt in
    o) ORGANIZATION="$OPTARG" ;;
    s) SERVICE_ID="$OPTARG" ;;
    k) API_KEYS="$API_KEYS $OPTARG" ;;
    f) JSON_FILE="$OPTARG" ;;
    h) show_help ;;
    *) show_help ;;
  esac
done

# Check if ORGANIZATION and SERVICE_ID are provided
if [ -z "$ORGANIZATION" ]; then
  echo "ERROR: Organization is required"
  show_help
fi

if [ -z "$SERVICE_ID" ]; then
  echo "ERROR: Service ID is required"
  show_help
fi

# Check if API keys or a JSON file are provided
if [ -z "$API_KEYS" ] && [ -z "$JSON_FILE" ]; then
  echo "ERROR: No API keys provided. Use -k KEY=VALUE or -f FILE"
  show_help
fi

# Export environment variables for initial connection
export VAULT_ADDR
export VAULT_TOKEN

echo "Adding OpenBAO service: $SERVICE_ID"
echo "================================================"

# Check if OpenBAO is accessible
echo "Checking if OpenBAO is accessible..."
if ! vault status > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to OpenBAO at $VAULT_ADDR"
  echo "Make sure OpenBAO is running and accessible."
  exit 1
fi

# Check if the organization exists
echo "Checking if organization '$ORGANIZATION' exists..."
ORGANIZATION_CHECK=$(vault namespace list)
if ! echo "$ORGANIZATION_CHECK" | grep -q "$ORGANIZATION/"; then
  echo "ERROR: Organization '$ORGANIZATION' does not exist."
  echo "First run the create_namespace.sh script with: ./run_in_container.sh create_namespace.sh --organization $ORGANIZATION"
  exit 1
fi
echo "Organization '$ORGANIZATION' found."

# Now that the organization is found, export VAULT_NAMESPACE
export VAULT_NAMESPACE=$ORGANIZATION

# Build the command for storing secrets
CMD="vault kv put services/$SERVICE_ID/api-keys"

# Add API keys to the command if they were provided via -k
for key_value in $API_KEYS; do
  CMD="$CMD $key_value"
done

# Process JSON file if provided
if [ -n "$JSON_FILE" ]; then
  if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: JSON file '$JSON_FILE' does not exist."
    exit 1
  fi

  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "ERROR: 'jq' is not installed. Install it with 'apt-get install jq' or 'yum install jq'."
    exit 1
  fi

  # Read the JSON file and add each key-value to the command
  for key in $(jq -r 'keys[]' "$JSON_FILE"); do
    value=$(jq -r ".[\"$key\"]" "$JSON_FILE")
    CMD="$CMD $key=$value"
  done
fi

# Execute the command
echo "Storing API keys for service '$SERVICE_ID'..."
eval $CMD

echo -e "\nCreating service-specific policy..."
cat > /tmp/$SERVICE_ID-policy.hcl << EOF
# Access to only $SERVICE_ID secrets
path "services/$SERVICE_ID/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write $SERVICE_ID-access /tmp/$SERVICE_ID-policy.hcl
echo "Policy '$SERVICE_ID-access' created."

echo -e "\n================================================"
echo "Service '$SERVICE_ID' successfully added!"
echo "================================================"
echo "The following API keys have been stored:"

# Show the stored keys (only the names, not the values)
vault kv get -format=json services/$SERVICE_ID/api-keys | jq -r '.data.data | keys[]'

echo -e "\nTo use these keys in '$ORGANIZATION':"
echo "1. Use the Vault node"
echo "2. Configure with the previously obtained Role ID and Secret ID"
echo "3. Use path: services/$SERVICE_ID/api-keys"
echo "================================================"
