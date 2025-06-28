#!/bin/bash
# Script voor het voorbereiden van een namespace in OpenBAO
# Auteur: Cascade
# Datum: 2025-06-28

set -e

# Help functie
show_help() {
  echo "Gebruik: $0 [opties]"
  echo ""
  echo "Opties:"
  echo "  -n, --namespace NAAM   Namespace naam (standaard: digi4care)"
  echo "  -p, --path PAD         Pad voor KV secrets engine (standaard: clients)"
  echo "  -r, --role NAAM        AppRole naam (standaard: namespace-role)"
  echo "  -t, --ttl TIJD         Token TTL in uren (standaard: 1h)"
  echo "  -h, --help             Toon deze help"
  echo ""
  echo "Voorbeeld: $0 --namespace marketing --path secrets --role api-access"
  exit 0
}

# Configuratie met standaardwaarden
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
NAMESPACE="digi4care"
SECRETS_PATH="clients"
ROLE_NAME=""
TOKEN_TTL="1h"

# Verwerk command line argumenten
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -p|--path)
      SECRETS_PATH="$2"
      shift
      shift
      ;;
    -r|--role)
      ROLE_NAME="$2"
      shift
      shift
      ;;
    -t|--ttl)
      TOKEN_TTL="$2"
      shift
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Onbekende optie: $1"
      show_help
      ;;
  esac
done

# Als geen role naam is opgegeven, gebruik namespace-role
if [ -z "$ROLE_NAME" ]; then
  ROLE_NAME="${NAMESPACE}-role"
fi

# Policy naam afgeleid van namespace
POLICY_NAME="${NAMESPACE}-read"

# In productie moet je de root token gebruiken die je krijgt bij het initialiseren
# In ontwikkeling kun je de standaard root token gebruiken
if [ -z "$VAULT_TOKEN" ]; then
  echo "WAARSCHUWING: Geen VAULT_TOKEN opgegeven."
  echo "- Voor ontwikkeling: gebruik 'export VAULT_TOKEN=root-token-dev'"
  echo "- Voor productie: gebruik de root token die je kreeg bij 'vault operator init'"
  exit 1
fi

echo "OpenBAO namespace '$NAMESPACE' voorbereiden"
echo "=================================="
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
echo -e "\nKV secrets engine inschakelen op pad '$SECRETS_PATH'..."
if vault secrets list | grep -q "^$SECRETS_PATH/"; then
  echo "KV secrets engine op pad '$SECRETS_PATH' bestaat al."
else
  vault secrets enable -path=$SECRETS_PATH kv-v2
  echo "KV secrets engine ingeschakeld op pad '$SECRETS_PATH'."
fi

# AppRole authenticatie inschakelen
echo -e "\nAppRole authenticatie inschakelen..."
if vault auth list | grep -q "^approle/"; then
  echo "AppRole authenticatie is al ingeschakeld."
else
  vault auth enable approle
  echo "AppRole authenticatie ingeschakeld."
fi

# Policy aanmaken
echo -e "\nPolicy aanmaken voor $NAMESPACE..."
cat > /tmp/${POLICY_NAME}.hcl << EOF
# Lees toegang tot alle secrets in $SECRETS_PATH
path "$SECRETS_PATH/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write $POLICY_NAME /tmp/${POLICY_NAME}.hcl
echo "Policy '$POLICY_NAME' aangemaakt."

# AppRole configureren
echo -e "\nAppRole voor $NAMESPACE configureren..."
vault write auth/approle/role/$ROLE_NAME \
    token_ttl=$TOKEN_TTL \
    token_max_ttl=24h \
    policies=$POLICY_NAME
echo "AppRole '$ROLE_NAME' geconfigureerd."

# Credentials ophalen
echo -e "\nCredentials ophalen voor $NAMESPACE..."
ROLE_ID=$(vault read -format=json auth/approle/role/$ROLE_NAME/role-id | jq -r .data.role_id)
SECRET_ID=$(vault write -f -format=json auth/approle/role/$ROLE_NAME/secret-id | jq -r .data.secret_id)

echo -e "\n================================================"
echo "Namespace '$NAMESPACE' is succesvol geconfigureerd!"
echo "================================================"
echo "Bewaar deze credentials voor gebruik:"
echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo "Namespace: $NAMESPACE"
echo "Role: $ROLE_NAME"
echo "Policy: $POLICY_NAME"
echo "Secrets Path: $SECRETS_PATH"
echo "================================================"
echo -e "\nGebruik het add_client.sh script om klanten toe te voegen."
