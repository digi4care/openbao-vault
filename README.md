# 🔐 OpenBAO Multi-Namespace Secrets Management

OpenBAO (Open Build, Authenticate, and Operate) is an open-source fork of HashiCorp Vault that remains fully open-source under the MPL 2.0 license. This setup is designed for managing secrets across multiple namespaces, ideal for multi-tenant applications and integrations with various systems like n8n.

## 📋 Table of Contents

- [What is OpenBAO?](#-what-is-openbao)
- [Why OpenBAO for Secrets Management?](#-why-openbao-for-secrets-management)
- [Development vs. Production Environment](#-development-vs-production-environment)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Available Scripts](#️-available-scripts)
- [User Management](#-user-management)
  - [User Roles](#user-roles)
  - [Creating an Admin](#creating-an-admin)
  - [Creating Client Operators](#creating-client-operators)
- [Managing Namespaces and Clients](#️-managing-namespaces-and-clients)
- [Application Integration](#-application-integration)
- [Step-by-Step: First Time Setup](#-step-by-step-first-time-setup)
  - [In Development](#in-development)
  - [In Production](#in-production)
- [Step-by-Step: Restarting in Production](#-step-by-step-restarting-in-production)
- [Frequently Asked Questions](#-frequently-asked-questions)

## 🔍 What is OpenBAO?

OpenBAO is an open-source fork of HashiCorp Vault that emerged after HashiCorp decided to change the license of their products from the open-source MPL 2.0 to the more restrictive Business Source License (BSL) in 2023.

OpenBAO offers the same core features as HashiCorp Vault:

- Secure storage of secrets (API keys, passwords, etc.)
- Encryption of sensitive data
- Access management with policies
- Various authentication methods

## 🤔 Why OpenBAO for Secrets Management?

When working with sensitive data like API keys, secure storage is essential. By using OpenBAO:

1. **Centralized secrets**: All sensitive data in one secure place
2. **Multi-tenant isolation**: Each namespace/client has its own isolated environment
3. **Dynamic access**: Applications can dynamically retrieve secrets based on namespace/client ID
4. **Enhanced security**: Central management of access rights and audit logs
5. **Flexible authentication**: Different authentication methods for different use cases

## 🔄 Development vs. Production Environment

### Development Environment

- **Storage type**: In-memory (temporary)
- **Security**: Minimal (for ease of development)
- **Startup**: Automatic, no manual steps required
- **Data persistence**: None, everything disappears on restart
- **Root Token**: Automatically generated on startup (shown in container logs)

### Production Environment

- **Storage type**: Persistent on disk
- **Security**: Maximum (sealed/unsealed concept)
- **Startup**: Manual steps required
- **Data persistence**: Full, everything is preserved
- **Root Token**: Generated during initialization, must be stored securely

## 📦 Installation

This repository contains a Docker-based setup for both development and production.

### Requirements

- Docker and Docker Compose
- Basic command line knowledge
- jq (for processing JSON in scripts)

### Directory Structure

```bash
openbao-vault/
├── docker-compose.dev.yml    # Docker Compose for development
├── docker-compose.prod.yml   # Docker Compose for production
├── .env.vault.dev            # Environment variables for development
├── .env.vault.prod           # Environment variables for production
├── scripts/
│   ├── init_openbao.sh       # Script for initial setup
│   ├── prepare_namespace.sh  # Script for namespace preparation
│   ├── add_client.sh         # Script for adding clients
│   ├── create_admin.sh       # Script for creating admin users
│   └── create_operator.sh    # Script for creating client operators
└── vault/                    # Data and configuration directories
    ├── data/                 # Persistent storage (automatically created)
    ├── config/               # Configuration files
    └── tls/                  # TLS certificates (for production)
```

## 🚀 Quick Start

1. **Start OpenBAO in development mode**

   ```bash
   # Build the custom Docker image with jq and start the container
   docker-compose -f docker-compose.dev.yml up -d --build
   ```

   The first time, you need to use the `--build` flag to build the custom Docker image that includes `jq` for JSON processing in the scripts.

2. **Get the root token**

   ```bash
   # Get the root token from the container logs
   docker logs openbao-dev | grep "Root Token"
   # Then export it
   export VAULT_TOKEN=<token-from-logs>
   ```

   Note: In development mode, OpenBAO is automatically initialized and unsealed. The `init_openbao.sh` script is primarily used in production to check if OpenBAO is accessible.

3. **Running scripts**

   The OpenBAO scripts need to run inside the Docker container. You can use the provided wrapper script to execute them:

   ```bash
   # The wrapper script automatically finds the root token if VAULT_TOKEN is not set
   ./run_in_container.sh prepare_namespace.sh --namespace example
   ```

   Or run them directly in the container:

   ```bash
   # Manual execution in the container
   docker exec -e VAULT_TOKEN=$VAULT_TOKEN openbao-dev /opt/bin/prepare_namespace.sh --namespace example
   ```

4. **Prepare a namespace**

   ```bash
   ./run_in_container.sh prepare_namespace.sh --namespace example
   ```

   This script sets up the basic configuration for a namespace and displays the credentials you'll need for application integration.

5. **Add a client**

   ```bash
   ./run_in_container.sh add_client.sh -c client1 -k slack=xoxb-12345 -k twitter=abcdef
   ```

6. **Create an admin user** (optional)

   ```bash
   ./run_in_container.sh create_admin.sh --username admin
   ```

7. **Create a client operator** (optional)

   ```bash
   ./run_in_container.sh create_operator.sh --namespace example --client client1 --username client1-operator
   ```

## 🐳 Docker Setup

This OpenBAO implementation uses a custom Docker setup with the following features:

- **Custom Docker image**: Based on the official OpenBAO image with added `jq` for JSON processing in scripts
- **Volume mounts**: Scripts are mounted as volumes instead of being copied into the image
  - This allows removing scripts in production after initial setup
  - Script changes are immediately available without rebuilding the image
- **Development vs Production**:
  - Development: Runs in `-dev` mode with automatic unseal and in-memory storage
  - Production: Uses configuration files and persistent storage

### Wrapper Script

The `run_in_container.sh` wrapper script makes it easy to run scripts inside the container:

```bash
./run_in_container.sh <script_name> [arguments]
```

This script:

1. Checks if the OpenBAO container is running
2. Automatically retrieves the root token from container logs if `VAULT_TOKEN` is not set
3. Makes the script executable in the container
4. Executes the script in the appropriate directory within the container

## 🛠️ Available Scripts

### init_openbao.sh

This script checks if OpenBAO is accessible and displays its status. It's primarily used in production environments, as in development mode OpenBAO is automatically initialized and unsealed.

### prepare_namespace.sh

This script prepares a namespace by:

- Creating a namespace
- Enabling the KV secrets engine
- Configuring AppRole authentication
- Creating policies
- Generating Role ID and Secret ID for the namespace

**Usage:**

```bash
./scripts/prepare_namespace.sh --namespace [name] --path [path] --role [role] --ttl [time]
```

### add_client.sh

This script adds a new client to OpenBAO with the appropriate secrets.

**Usage with command-line parameters:**

```bash
./scripts/add_client.sh -c client1 -k slack=xoxb-12345 -k twitter=abcdef
```

**Usage with JSON file:**

```bash
./scripts/add_client.sh -c client2 -f keys.json
```

Example of a keys.json file:

```json
{
  "slack": "xoxb-67890",
  "twitter": "ghijkl",
  "api_key": "your-api-key"
}
```

### create_global_admin.sh

This script creates a global admin user who can manage all namespaces. This admin replaces the root token for daily use.

**Usage:**

```bash
./run_in_container.sh create_global_admin.sh --username admin
```

**Permissions:**

- Full system access (can manage all namespaces, policies, auth methods, etc.)
- Can create and manage all secrets engines
- Can create and manage all policies
- Can create and manage all namespaces

### create_operator.sh

This script creates an operator for a specific client who can only manage that client's secrets within a specific namespace.

**Usage:**

```bash
./run_in_container.sh create_operator.sh --namespace example --client client1 --username client1-operator
```

**Permissions:**

- Limited to a single client's secrets within the specified namespace
- Can read/write only that client's secrets
- Cannot access other clients' secrets or system configuration

### User Access Hierarchy

The system implements a hierarchical access model:

1. **Root Token**: Full system access, should only be used for initial setup and emergencies
2. **Admin Users**: Global administrators who can manage the entire system
3. **Operator Users**: Client-specific operators who can only manage their assigned client's secrets

This follows the principle of least privilege - users only get access to what they need to perform their specific tasks.

## 👥 User Management

### User Roles

OpenBAO uses a hierarchy of user roles for secure management:

1. **Root Token**

   - Highest level of access
   - Only use for initial setup and emergencies
   - Should be revoked after use
   - Has access to all functions and data

2. **Admin**

   - Global administrator who can manage all namespaces
   - Can create namespaces, auth methods, and policies
   - Replaces the root token for daily management
   - Created via `create_global_admin.sh`

3. **Operators**

   - One operator per client/namespace
   - Can only manage the secrets of that specific client
   - No access to system settings or other clients
   - Created via `create_operator.sh`

4. **AppRole**
   - For applications like n8n
   - Read-only access to specific secrets
   - Short-lived tokens
   - Created via `prepare_namespace.sh`

### Creating a Global Admin

Use the `create_global_admin.sh` script to create a global admin:

```bash
./scripts/create_global_admin.sh --username admin
```

The admin gets full rights to:

- Manage namespaces
- Configure auth methods
- Manage secrets engines
- Create policies
- Access all secrets

After creating an admin, you can choose to revoke the root token for better security:

```bash
vault token revoke -self
```

**Note**: If you revoke the root token, you can no longer log in as root. In emergencies, you can always generate a new root token using the unseal keys:

```bash
vault operator generate-root -init
# Follow the instructions and use at least 3 unseal keys
```

### Creating Client Operators

Use the `create_operator.sh` script to create an operator for each client:

```bash
./scripts/create_operator.sh --namespace example --client client1 --username client1-operator
```

The operator gets limited rights:

- Full access to the secrets of only that specific client
- Read-only access to the client list
- No access to other clients or system settings

Operators can log in with:

```bash
export VAULT_NAMESPACE=example
vault login -method=userpass username=client1-operator
```

## 🗂️ Managing Namespaces and Clients

### Creating a New Namespace

Use the `prepare_namespace.sh` script:

```bash
./scripts/prepare_namespace.sh --namespace marketing --path secrets --role api-access
```

### Adding a New Client

Use the `add_client.sh` script as described above.

### Viewing Secrets

```bash
# Set the namespace
export VAULT_NAMESPACE=example

# View a client's secrets
vault kv get clients/client1/api-keys
```

### Updating Secrets

```bash
# Update a client's secrets
vault kv put clients/client1/api-keys slack=new-token twitter=new-token
```

## 🔌 Application Integration

### Integration with n8n

1. Use the Vault node in n8n
2. Configure it with the Role ID and Secret ID from the `prepare_namespace.sh` script
3. Use the path `clients/client-id/api-keys` to access secrets

### Integration with Other Applications

For other applications, you can use:

1. **Direct API access**: Using the OpenBAO HTTP API
2. **Client libraries**: Official libraries available for various languages
3. **AppRole authentication**: For secure machine-to-machine communication

## 📝 Step-by-Step: First Time Setup

### In Development

```bash
# Start the container
docker-compose -f docker-compose.dev.yml up -d

# Get the root token from logs
docker logs openbao-dev | grep "Root Token"

# Set the root token
export VAULT_TOKEN=<token-from-logs>

# Optional: Check if OpenBAO is accessible
# ./scripts/init_openbao.sh

# Prepare a namespace
./scripts/prepare_namespace.sh --namespace example
```

### In Production

1. **Start OpenBAO in production mode**:

   ```bash
   docker-compose -f docker-compose.prod.yml up -d --build
   ```

   The first time, you need to use the `--build` flag to build the custom Docker image that includes `jq` for JSON processing in the scripts.

2. **Initialize OpenBAO** (you only do this once):

   ```bash
   docker exec -it vault-prod sh
   vault operator init
   ```

3. **Save the output securely!** You'll get:

   - 5 unseal keys (by default)
   - 1 root token

   For example:

   ```text
   Unseal Key 1: a3EfGhIjK4lMnOpQrStUvWxYz0123456789ABCDEFG
   Unseal Key 2: bCdEfGhIjK4lMnOpQrStUvWxYz0123456789ABCDEF
   Unseal Key 3: cDeFgHiJkL4mNoPqRsTuVwXyZ0123456789ABCDE
   Unseal Key 4: dEfGhIjKlM4nOpQrStUvWxYz0123456789ABCDE
   Unseal Key 5: eFgHiJkLmN4oPqRsTuVwXyZ0123456789ABCD

   Root Token: hvs.UvWxYz0123456789ABCDEFGhIjKlMnOpQrSt
   ```

4. **Unseal OpenBAO** (use 3 of the 5 keys):

   ```bash
   vault operator unseal [Unseal Key 1]
   vault operator unseal [Unseal Key 2]
   vault operator unseal [Unseal Key 3]
   ```

5. **Log in with the root token**:

   ```bash
   vault login [Root Token]
   ```

6. **Exit the container**:

   ```bash
   exit
   ```

7. **Set up your environment**:

   ```bash
   export VAULT_ADDR=http://127.0.0.1:8200
   export VAULT_TOKEN=[Root Token]
   ```

8. **Create an admin user** (recommended):

   ```bash
   # For production, run scripts directly in the container
   docker exec -e VAULT_TOKEN=$VAULT_TOKEN openbao-prod /opt/bin/create_admin.sh --username admin
   ```

9. **Prepare namespaces and add clients**:

   ```bash
   docker exec -e VAULT_TOKEN=$VAULT_TOKEN openbao-prod /opt/bin/prepare_namespace.sh --namespace example
   docker exec -e VAULT_TOKEN=$VAULT_TOKEN openbao-prod /opt/bin/add_client.sh -c client1 -k api_key=12345
   ```

## 🔄 Step-by-Step: Restarting in Production

When you restart the OpenBAO container in production, it will be sealed. Follow these steps to unseal it:

1. **Check the status**:

   ```bash
   export VAULT_ADDR=http://127.0.0.1:8200
   vault status
   ```

   You should see `Sealed: true`.

2. **Unseal OpenBAO** (use 3 of the 5 keys):

   ```bash
   vault operator unseal [Unseal Key 1]
   vault operator unseal [Unseal Key 2]
   vault operator unseal [Unseal Key 3]
   ```

3. **Log in**: Use the same root token as during initialization or use your admin user

   ```bash
   vault login [Root Token]
   # OR
   vault login -method=userpass username=admin
   ```

## ❓ Frequently Asked Questions

### What's the difference between a root token and a regular token?

A root token has unlimited access to all functions and data in OpenBAO. A regular token only has access to specific paths and functions, based on the assigned policies.

### How long does a token remain valid?

In the development environment: until the container is restarted.
In production: until the token is revoked or expires (if a TTL is set).

### What happens if I lose my root token?

In development: restart the container and use the new token from the logs.
In production: use the unseal keys to generate a new root token with `vault operator generate-root`.

### Do I need to unseal OpenBAO after every restart?

Yes, in the production environment, you must unseal OpenBAO after each restart with at least 3 of the 5 unseal keys.

### Can I automate the unsealing process?

Technically yes, but this is discouraged from a security perspective. The purpose of sealing is precisely to require manual intervention during a restart.

### What's the difference between an admin and an operator?

An admin has global rights to manage the entire system, including all namespaces. An operator only has rights to manage the secrets of one specific client within a namespace.

### Should I revoke the root token after use?

It's good security practice to revoke the root token after creating an admin user, but it's not mandatory. Keep in mind that:

- If you revoke the root token, you can no longer log in as root
- You can always generate a new root token with `vault operator generate-root` and your unseal keys
- The admin can perform all daily management tasks without the security risk of an active root token

### How can a client operator log in?

A client operator must first set the namespace and can then log in with the userpass method:

```bash
export VAULT_NAMESPACE=example
vault login -method=userpass username=client1-operator
```

### What's the difference between "sealed" and "unsealed"?

- **Sealed**: OpenBAO is locked, the encryption key is not in memory, data is inaccessible
- **Unsealed**: OpenBAO is unlocked, the encryption key is loaded in memory, data is accessible

### How many unseal keys do I need?

By default, OpenBAO generates 5 keys, of which you need 3 to unseal (this is called "Shamir's Secret Sharing"). You can adjust this during initialization.

### Is this setup secure for production?

The production setup is secured with the following measures:

- OpenBAO is only locally accessible (127.0.0.1:8200)
- TLS termination is handled by a reverse proxy like LiteSpeed
- Scripts are removed from the production container
- Swapping is disabled (mem_swappiness: 0)

For additional security, we recommend:

- Setting up firewall rules for the reverse proxy
- Making regular backups of the data directory
- Enabling audit logging
