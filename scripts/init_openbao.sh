#!/bin/bash
# Script voor initiële setup van OpenBAO voor n8n integratie
# Auteur: Cascade
# Datum: 2025-06-28

set -e

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:49281"}
VAULT_TOKEN=${VAULT_TOKEN:-"root-token-dev"}
NAMESPACE="n8n"

echo "OpenBAO initialisatie script voor n8n integratie"
echo "================================================"
echo "Verbinding maken met OpenBAO op $VAULT_ADDR"

# Exporteer omgevingsvariabelen
export VAULT_ADDR
export VAULT_TOKEN

# Controleer of OpenBAO bereikbaar is
echo "Controleren of OpenBAO bereikbaar is..."
if ! vault status > /dev/null 2>&1; then
  echo "FOUT: Kan geen verbinding maken met OpenBAO op $VAULT_ADDR"
  echo "Zorg ervoor dat OpenBAO draait en bereikbaar is."
  exit 1
fi

echo "OpenBAO is bereikbaar. Status:"
vault status | grep "Seal Type\|Version"

# Namespace aanmaken
echo -e "\nNamespace '$NAMESPACE' aanmaken..."
if vault namespace list | grep -q "^$NAMESPACE/"; then
  echo "Namespace '$NAMESPACE' bestaat al."
else
  vault namespace create $NAMESPACE
  echo "Namespace '$NAMESPACE' aangemaakt."
fi

# Selecteer de namespace voor volgende commando's
export VAULT_NAMESPACE=$NAMESPACE
echo "Namespace geselecteerd: $VAULT_NAMESPACE"

# KV secrets engine inschakelen
echo -e "\nKV secrets engine inschakelen op pad 'clients'..."
if vault secrets list | grep -q "^clients/"; then
  echo "KV secrets engine op pad 'clients' bestaat al."
else
  vault secrets enable -path=clients kv-v2
  echo "KV secrets engine ingeschakeld op pad 'clients'."
fi

# AppRole authenticatie inschakelen
echo -e "\nAppRole authenticatie inschakelen..."
if vault auth list | grep -q "^approle/"; then
  echo "AppRole authenticatie is al ingeschakeld."
else
  vault auth enable approle
  echo "AppRole authenticatie ingeschakeld."
fi

# Policy aanmaken voor n8n
echo -e "\nPolicy aanmaken voor n8n..."
cat > /tmp/n8n-read-policy.hcl << EOF
# Lees toegang tot alle klant secrets
path "clients/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write n8n-read /tmp/n8n-read-policy.hcl
echo "Policy 'n8n-read' aangemaakt."

# AppRole voor n8n configureren
echo -e "\nAppRole voor n8n configureren..."
vault write auth/approle/role/n8n-role \
    token_ttl=1h \
    token_max_ttl=24h \
    policies=n8n-read
echo "AppRole 'n8n-role' geconfigureerd."

# Credentials ophalen voor n8n
echo -e "\nCredentials ophalen voor n8n..."
ROLE_ID=$(vault read -format=json auth/approle/role/n8n-role/role-id | jq -r .data.role_id)
SECRET_ID=$(vault write -f -format=json auth/approle/role/n8n-role/secret-id | jq -r .data.secret_id)

echo -e "\n================================================"
echo "OpenBAO is succesvol geconfigureerd voor n8n!"
echo "================================================"
echo "Bewaar deze credentials voor gebruik in n8n:"
echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo "Namespace: $NAMESPACE"
echo "================================================"
echo -e "\nGebruik het add_client.sh script om klanten toe te voegen."
