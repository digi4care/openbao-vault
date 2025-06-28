#!/bin/sh
# Script voor het toevoegen van een nieuwe klant in OpenBAO
# Auteur: Chris Engelhard <chris@chrisengelhard.nl>
# Datum: 2025-06-28

set -e

# Functie voor het tonen van hulp
show_help() {
  echo "Gebruik: $0 -n NAMESPACE -c CLIENT_ID [-k KEY1=VALUE1] [-k KEY2=VALUE2] ..."
  echo
  echo "Opties:"
  echo "  -n NAMESPACE    Verplicht: Namespace waarin de klant wordt toegevoegd"
  echo "  -c CLIENT_ID    Verplicht: ID van de klant (bijv. 'klant1')"
  echo "  -k KEY=VALUE    Optioneel: API key in formaat NAAM=WAARDE (meerdere -k opties mogelijk)"
  echo "  -f FILE         Optioneel: Pad naar JSON bestand met API keys"
  echo "  -h              Toon deze hulp"
  echo
  echo "Voorbeelden:"
  echo "  $0 -n service -c klant1 -k slack=xoxb-12345 -k twitter=abcdef"
  echo "  $0 -n service -c klant2 -f keys.json"
  exit 1
}

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"root-token-dev"}
NAMESPACE=""
CLIENT_ID=""
API_KEYS=""
JSON_FILE=""

# Verwerk command line argumenten
while getopts "n:c:k:f:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    c) CLIENT_ID="$OPTARG" ;;
    k) API_KEYS="$API_KEYS $OPTARG" ;;
    f) JSON_FILE="$OPTARG" ;;
    h) show_help ;;
    *) show_help ;;
  esac
done

# Controleer of NAMESPACE en CLIENT_ID zijn opgegeven
if [ -z "$NAMESPACE" ]; then
  echo "FOUT: Namespace is verplicht"
  show_help
fi

if [ -z "$CLIENT_ID" ]; then
  echo "FOUT: Klant ID is verplicht"
  show_help
fi

# Controleer of er API keys zijn opgegeven of een JSON bestand
if [ -z "$API_KEYS" ] && [ -z "$JSON_FILE" ]; then
  echo "FOUT: Geen API keys opgegeven. Gebruik -k KEY=VALUE of -f FILE"
  show_help
fi

# Exporteer omgevingsvariabelen voor initiële verbinding
export VAULT_ADDR
export VAULT_TOKEN

echo "OpenBAO klant toevoegen: $CLIENT_ID"
echo "================================================"

# Controleer of OpenBAO bereikbaar is
echo "Controleren of OpenBAO bereikbaar is..."
if ! vault status > /dev/null 2>&1; then
  echo "FOUT: Kan geen verbinding maken met OpenBAO op $VAULT_ADDR"
  echo "Zorg ervoor dat OpenBAO draait en bereikbaar is."
  exit 1
fi

# Controleer of de namespace bestaat
echo "Controleren of namespace '$NAMESPACE' bestaat..."
NAMESPACE_CHECK=$(vault namespace list)
if ! echo "$NAMESPACE_CHECK" | grep -q "$NAMESPACE/"; then
  echo "FOUT: Namespace '$NAMESPACE' bestaat niet."
  echo "Voer eerst het prepare_namespace.sh script uit met: ./run_in_container.sh prepare_namespace.sh --namespace $NAMESPACE"
  exit 1
fi
echo "Namespace '$NAMESPACE' gevonden."

# Nu de namespace is gevonden, exporteer VAULT_NAMESPACE
export VAULT_NAMESPACE=$NAMESPACE

# Bouw het commando voor het opslaan van secrets
CMD="vault kv put clients/$CLIENT_ID/api-keys"

# Voeg API keys toe aan het commando als ze zijn opgegeven via -k
for key_value in $API_KEYS; do
  CMD="$CMD $key_value"
done

# Verwerk JSON bestand als dat is opgegeven
if [ -n "$JSON_FILE" ]; then
  if [ ! -f "$JSON_FILE" ]; then
    echo "FOUT: JSON bestand '$JSON_FILE' bestaat niet."
    exit 1
  fi

  # Controleer of jq is geïnstalleerd
  if ! command -v jq &> /dev/null; then
    echo "FOUT: 'jq' is niet geïnstalleerd. Installeer het met 'apt-get install jq' of 'yum install jq'."
    exit 1
  fi

  # Lees het JSON bestand en voeg elke key-value toe aan het commando
  for key in $(jq -r 'keys[]' "$JSON_FILE"); do
    value=$(jq -r ".[\"$key\"]" "$JSON_FILE")
    CMD="$CMD $key=$value"
  done
fi

# Voer het commando uit
echo "API keys opslaan voor klant '$CLIENT_ID'..."
eval $CMD

echo -e "\nKlant-specifieke policy aanmaken..."
cat > /tmp/$CLIENT_ID-policy.hcl << EOF
# Toegang tot alleen $CLIENT_ID secrets
path "clients/$CLIENT_ID/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write $CLIENT_ID-access /tmp/$CLIENT_ID-policy.hcl
echo "Policy '$CLIENT_ID-access' aangemaakt."

echo -e "\n================================================"
echo "Klant '$CLIENT_ID' is succesvol toegevoegd!"
echo "================================================"
echo "De volgende API keys zijn opgeslagen:"

# Toon de opgeslagen keys (alleen de namen, niet de waarden)
vault kv get -format=json clients/$CLIENT_ID/api-keys | jq -r '.data.data | keys[]'

echo -e "\nOm deze keys te gebruiken in '$NAMESPACE':"
echo "1. Gebruik de Vault node"
echo "2. Configureer met de eerder verkregen Role ID en Secret ID"
echo "3. Gebruik pad: clients/$CLIENT_ID/api-keys"
echo "================================================"
