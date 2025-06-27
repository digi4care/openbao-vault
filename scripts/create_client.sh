#!/bin/bash

# Script om een nieuwe klant toe te voegen aan Vault
# Gebruik: ./create_client.sh klantnaam

# Controleer of er een klantnaam is opgegeven
if [ -z "$1" ]; then
  echo "Gebruik: $0 <klantnaam>"
  exit 1
fi

KLANT_ID="$1"
POLICY_FILE="policies/${KLANT_ID}-policy.hcl"
POLICY_NAME="${KLANT_ID}"

# Maak de policies directory als deze nog niet bestaat
mkdir -p policies

# Maak het policy bestand
cat > $POLICY_FILE << EOF
# Policy voor ${KLANT_ID}
# Toegang tot alleen de eigen klantgegevens
path "secret/data/klanten/${KLANT_ID}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Lees toegang tot eigen klantmap
path "secret/metadata/klanten/${KLANT_ID}/*" {
  capabilities = ["list"]
}

# Geen toegang tot gegevens van andere klanten
path "secret/data/klanten/*" {
  capabilities = []
}
EOF

echo "Policy bestand aangemaakt: $POLICY_FILE"

# Controleer of we verbinding kunnen maken met Vault
if ! vault status > /dev/null 2>&1; then
  echo "Kan geen verbinding maken met Vault. Zorg ervoor dat Vault draait en dat je bent ingelogd."
  exit 1
fi

# Upload de policy naar Vault
echo "Policy uploaden naar Vault..."
vault policy write $POLICY_NAME $POLICY_FILE

# Maak een AppRole voor de klant
echo "AppRole aanmaken voor $KLANT_ID..."
vault auth enable -path=approle approle 2>/dev/null || true
vault write auth/approle/role/$KLANT_ID \
    token_policies="$POLICY_NAME" \
    token_ttl=8h \
    token_max_ttl=24h

# Haal de RoleID op
ROLE_ID=$(vault read -format=json auth/approle/role/$KLANT_ID/role-id | jq -r .data.role_id)

# Genereer een SecretID
SECRET_ID=$(vault write -f -format=json auth/approle/role/$KLANT_ID/secret-id | jq -r .data.secret_id)

# Maak de klantmap aan in Vault als deze nog niet bestaat
echo "Klantmap aanmaken in Vault..."
vault kv put secret/klanten/$KLANT_ID/info naam="$KLANT_ID" aangemaakt="$(date +%Y-%m-%d)"

# Toon de toegangsgegevens
echo ""
echo "==== TOEGANGSGEGEVENS VOOR $KLANT_ID ===="
echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo ""
echo "Bewaar deze gegevens op een veilige plaats!"
echo ""
echo "De klant kan inloggen met:"
echo "vault write auth/approle/login role_id=\"$ROLE_ID\" secret_id=\"$SECRET_ID\""
echo ""
echo "Of via de API:"
echo "curl --request POST --data '{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}' https://vault.hummer.ai:49281/v1/auth/approle/login"
echo ""
echo "Klant is succesvol aangemaakt!"
