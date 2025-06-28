#!/bin/bash
# Script voor het aanmaken van een client operator in OpenBAO
# Auteur: Cascade
# Datum: 2025-06-28

set -e

# Help functie
show_help() {
  echo "Gebruik: $0 [opties]"
  echo ""
  echo "Dit script maakt een operator aan voor een specifieke client/namespace."
  echo "Deze operator kan alleen de secrets van die specifieke client beheren."
  echo ""
  echo "Opties:"
  echo "  -n, --namespace NAAM   Namespace naam (verplicht)"
  echo "  -c, --client ID        Client ID (verplicht)"
  echo "  -u, --username NAAM    Operator gebruikersnaam (verplicht)"
  echo "  -p, --password WACHT   Operator wachtwoord (optioneel, wordt anders gevraagd)"
  echo "  -h, --help             Toon deze help"
  echo ""
  echo "Voorbeeld: $0 --namespace digi4care --client klant123 --username klant123-operator"
  exit 1
}

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
NAMESPACE=""
CLIENT_ID=""
USERNAME=""
PASSWORD=""

# In productie moet je een admin token gebruiken, niet de root token
if [ -z "$VAULT_TOKEN" ]; then
  echo "WAARSCHUWING: Geen VAULT_TOKEN opgegeven."
  echo "Gebruik een admin token of de root token (alleen voor setup)."
  exit 1
fi

# Verwerk command line argumenten
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -c|--client)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    -u|--username)
      USERNAME="$2"
      shift
      shift
      ;;
    -p|--password)
      PASSWORD="$2"
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

# Controleer of verplichte parameters zijn opgegeven
if [ -z "$NAMESPACE" ]; then
  echo "FOUT: Namespace is verplicht"
  show_help
fi

if [ -z "$CLIENT_ID" ]; then
  echo "FOUT: Client ID is verplicht"
  show_help
fi

if [ -z "$USERNAME" ]; then
  echo "FOUT: Gebruikersnaam is verplicht"
  show_help
fi

# Vraag om wachtwoord als het niet is opgegeven
if [ -z "$PASSWORD" ]; then
  echo -n "Voer wachtwoord in voor operator $USERNAME: "
  read -s PASSWORD
  echo ""
  
  echo -n "Voer wachtwoord nogmaals in: "
  read -s PASSWORD_CONFIRM
  echo ""
  
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "FOUT: Wachtwoorden komen niet overeen"
    exit 1
  fi
fi

# Exporteer omgevingsvariabelen
export VAULT_ADDR
export VAULT_TOKEN

echo "OpenBAO client operator aanmaken: $USERNAME voor client $CLIENT_ID in namespace $NAMESPACE"
echo "================================================================================"

# Controleer of OpenBAO bereikbaar is
echo "Controleren of OpenBAO bereikbaar is..."
if ! vault status > /dev/null 2>&1; then
  echo "FOUT: Kan geen verbinding maken met OpenBAO op $VAULT_ADDR"
  echo "Zorg ervoor dat OpenBAO draait en bereikbaar is."
  exit 1
fi

# Controleer of de namespace bestaat
echo -e "\nControleren of namespace $NAMESPACE bestaat..."
if ! vault namespace list | grep -q "^$NAMESPACE/"; then
  echo "FOUT: Namespace $NAMESPACE bestaat niet"
  echo "Maak eerst de namespace aan met prepare_namespace.sh"
  exit 1
fi

# Selecteer de namespace
export VAULT_NAMESPACE=$NAMESPACE
echo "Namespace geselecteerd: $VAULT_NAMESPACE"

# Userpass authenticatie inschakelen als het nog niet is ingeschakeld
echo -e "\nUserpass authenticatie inschakelen in namespace $NAMESPACE..."
if ! vault auth list | grep -q "^userpass/"; then
  vault auth enable userpass
  echo "Userpass authenticatie ingeschakeld."
else
  echo "Userpass authenticatie is al ingeschakeld."
fi

# Operator policy aanmaken
echo -e "\nOperator policy aanmaken voor client $CLIENT_ID..."
POLICY_NAME="${CLIENT_ID}-operator"

cat > /tmp/${POLICY_NAME}.hcl << EOF
# Operator policy voor client $CLIENT_ID
# Geeft volledige toegang tot de secrets van deze client

# Lees/schrijf toegang tot client secrets
path "clients/$CLIENT_ID/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Alleen lezen van clients lijst
path "clients/" {
  capabilities = ["list"]
}

# Alleen lezen van eigen client
path "clients/$CLIENT_ID" {
  capabilities = ["list", "read"]
}
EOF

vault policy write $POLICY_NAME /tmp/${POLICY_NAME}.hcl
echo "Policy '$POLICY_NAME' aangemaakt."

# Operator gebruiker aanmaken
echo -e "\nOperator gebruiker aanmaken..."
vault write auth/userpass/users/$USERNAME \
  password="$PASSWORD" \
  policies=$POLICY_NAME

echo -e "\n================================================================================"
echo "Client operator is succesvol aangemaakt!"
echo "================================================================================"
echo "Namespace: $NAMESPACE"
echo "Client: $CLIENT_ID"
echo "Gebruikersnaam: $USERNAME"
echo "Policy: $POLICY_NAME"
echo "================================================================================"
echo -e "\nDe operator kan inloggen met:"
echo "export VAULT_NAMESPACE=$NAMESPACE"
echo "vault login -method=userpass username=$USERNAME"
echo "================================================================================"
