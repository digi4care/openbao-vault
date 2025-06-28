# Using AppRole Authentication with OpenBAO

A guide for retrieving service data from OpenBAO using AppRole authentication.

## What you need

- AppRole credentials for OpenBAO (Role ID and Secret ID)
- A way to make HTTP requests (API client, programming language, integration platform, etc.)

## Complete Token Lifecycle Workflow

This guide walks you through the complete lifecycle of working with OpenBAO tokens:

1. Initial authentication with AppRole
2. Using the token to access secrets
3. Checking token status
4. Renewing the token
5. Handling token expiration

### Step 1: Initial Authentication

First, authenticate with your AppRole credentials to get a token:

```bash
# Login with AppRole credentials
curl --request POST \
  --url https://example.com/v1/auth/approle/login \
  --header 'Content-Type: application/json' \
  --data '{
  "role_id": "YOUR-ROLE-ID",
  "secret_id": "YOUR-SECRET-ID"
}'
```

You'll receive a response containing your token and its properties:

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
    "lease_duration": 3600,       # Token valid for 1 hour
    "renewable": true,           # Can be renewed
    "entity_id": "4cf33e44-0ec3-0a8b-0d10-7a8e18fe314b",
    "token_type": "service",
    "orphan": true
  }
}
```

Note the important fields:

- `client_token`: The token you'll use for subsequent requests
- `lease_duration`: How long the token is valid (in seconds)
- `renewable`: Whether the token can be renewed

Store your token securely:

```bash
# Set the organization namespace and token
export VAULT_NAMESPACE="acme-corp"
export VAULT_TOKEN="hvs.CAESIJnR0...truncated...Kw5c"
```

### Step 2: Using the Token to Access Secrets

Now use your token to retrieve secrets:

```bash
# Get API keys for a service
curl --request GET \
  --url https://example.com/v1/services/payment/api-keys \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

Response format:

```json
{
  "data": {
    "data": {                        # Note the nested data structure
      "stripe": "sk_test_51HGGWaLknNgQbT...",
      "paypal": "client_id_AbCdEf123456..."
    }
  }
}
```

You can access different types of secrets with the same token (as permitted by your policies):

```bash
# Get database credentials
curl --request GET \
  --url https://example.com/v1/services/payment/database \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

### Step 3: Checking Token Status

Before your token expires, you may want to check its status:

```bash
curl --request GET \
  --url https://example.com/v1/auth/token/lookup-self \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

This returns information about your token, including:

- Remaining time until expiration
- Whether it's renewable
- Associated policies

### Step 4: Renewing the Token

If your token is about to expire but is renewable (the `renewable` field was `true`), you can extend its lifetime:

```bash
curl --request POST \
  --url https://example.com/v1/auth/token/renew-self \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --header "X-Vault-Namespace: $VAULT_NAMESPACE"
```

This will extend the token's lifetime by its original TTL (Time-To-Live), but never beyond its maximum TTL.

The response will include the updated token information:

```json
{
  "auth": {
    "client_token": "hvs.CAESIJnR0...truncated...Kw5c",  # Same token
    "policies": ["default", "service-policy"],
    "token_policies": ["default", "service-policy"],
    "metadata": {
      "role_name": "service-role"
    },
    "lease_duration": 3600,       # Reset to original TTL
    "renewable": true
  }
}
```

### Step 5: Handling Token Expiration

When a token can no longer be renewed (reached max TTL) or has expired:

1. You'll receive a `401 Unauthorized` error when trying to use it
2. You need to authenticate again with your AppRole credentials (return to Step 1)

```bash
# Re-authenticate when token expires
curl --request POST \
  --url https://example.com/v1/auth/approle/login \
  --header 'Content-Type: application/json' \
  --data '{
  "role_id": "YOUR-ROLE-ID",
  "secret_id": "YOUR-SECRET-ID"
}'
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

> **IMPORTANT**: Knowing only the URL is NOT sufficient to access the data. OpenBAO requires valid authentication (Role ID + Secret ID) and proper authorization via policies. Without these credentials, all requests will be denied, regardless of whether the URL is correct.
