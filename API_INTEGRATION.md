# Using AppRole Authentication with OpenBAO

A guide for retrieving service data from OpenBAO using AppRole authentication.

## What you need

- AppRole credentials for OpenBAO (Role ID and Secret ID)
- A way to make HTTP requests (API client, programming language, integration platform, etc.)

## Step 1: Authentication with AppRole

To authenticate with OpenBAO using AppRole, you need to:

1. Obtain a Role ID and Secret ID from your administrator
2. Exchange these credentials for a Vault token
3. Use this token for subsequent API requests

### Authentication Process:

1. **Login with AppRole credentials**:

```bash
# Using curl
curl --request POST \
  --url https://example.com/v1/auth/approle/login \
  --header 'Content-Type: application/json' \
  --data '{
  "role_id": "YOUR-ROLE-ID",
  "secret_id": "YOUR-SECRET-ID"
}'
```

1. **Extract the client token** from the response:

```json
{
  "auth": {
    "client_token": "hvs.CAESIJnR0...truncated...Kw5c",
    "accessor": "hvs.CnoaYP...truncated...q6E",
    "policies": ["default", "service-policy"],
    "token_policies": ["default", "service-policy"],
    "metadata": {
      "role_name": "service-role"
    },
    "lease_duration": 3600,
    "renewable": true,
    "entity_id": "4cf33e44-0ec3-0a8b-0d10-7a8e18fe314b",
    "token_type": "service",
    "orphan": true
  }
}
```

1. **Use the token** for subsequent requests:

```bash
# Set the organization namespace and token
export VAULT_NAMESPACE="acme-corp"
export VAULT_TOKEN="hvs.CAESIJnR0...truncated...Kw5c"

# Using curl with the token
curl --request GET \
  --url https://example.com/v1/services/payment/api-keys \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

> **IMPORTANT**: Knowing only the URL is NOT sufficient to access the data. OpenBAO requires valid authentication (Role ID + Secret ID) and proper authorization via policies. Without these credentials, all requests will be denied, regardless of whether the URL is correct.

## Step 2: Working with the data

When you retrieve data from OpenBAO, it is typically returned in this format:

```json
{
  "data": {
    "data": {
      "key1": "value1",
      "key2": "value2"
    }
  }
}
```

To extract specific values, you'll need to navigate through this nested structure to access the inner `data` object.

## Examples

### Example 1: Retrieving an API key

```bash
# Get API keys for a service
curl --request GET \
  --url https://example.com/v1/services/payment/api-keys \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: acme-corp"

# Response
{
  "data": {
    "data": {
      "stripe": "sk_test_51HGGWaLknNgQbT...",
      "paypal": "client_id_AbCdEf123456..."
    }
  }
}
```

### Example 2: Retrieving database credentials

```bash
# Get database credentials
curl --request GET \
  --url https://example.com/v1/services/payment/database \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: acme-corp"

# Response
{
  "data": {
    "data": {
      "username": "payment_service",
      "password": "secure_password_123",
      "host": "db.example.com",
      "port": "5432"
    }
  }
}
```

## Troubleshooting

### Common Error Codes

- **401 Unauthorized**: Your authentication token is missing, expired, or invalid

  - Solution: Re-authenticate using your AppRole credentials to get a new token

- **403 Forbidden**: Your token is valid but doesn't have sufficient permissions

  - Solution: Ask your administrator to update the policy associated with your AppRole

- **404 Not Found**: The requested path doesn't exist

  - Solution: Verify the organization, service name, and path are correct

- **Empty response**: The path exists but contains no data
  - Solution: Check if data has been stored at that location

### Checking Token Status

To check if your token is still valid and see its permissions:

```bash
curl --request GET \
  --url https://example.com/v1/auth/token/lookup-self \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

### Renewing a Token

If your token is about to expire but is renewable:

```bash
curl --request POST \
  --url https://example.com/v1/auth/token/renew-self \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```
