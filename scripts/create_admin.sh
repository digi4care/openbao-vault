#!/bin/bash
# Script voor het aanmaken van een globale admin gebruiker in OpenBAO
# Auteur: Cascade
# Datum: 2025-06-28

set -e

# Help functie
show_help() {
  echo "Gebruik: $0 [opties]"
  echo ""
  echo "Dit script maakt een globale admin gebruiker aan die alle namespaces kan beheren."
  echo "Deze admin vervangt de root token voor dagelijks gebruik."
  echo ""
  echo "Opties:"
  echo "  -u, --username NAAM    Admin gebruikersnaam (verplicht)"
  echo "  -p, --password WACHT   Admin wachtwoord (optioneel, wordt anders gevraagd)"
  echo "  -h, --help             Toon deze help"
  echo ""
  echo "Voorbeeld: $0 --username admin"
  exit 1
}

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
USERNAME=""
PASSWORD=""

# In productie moet je de root token gebruiken die je krijgt bij het initialiseren
# In ontwikkeling kun je de standaard root token gebruiken
if [ -z "$VAULT_TOKEN" ]; then
  echo "WAARSCHUWING: Geen VAULT_TOKEN opgegeven."
  echo "- Voor ontwikkeling: gebruik 'export VAULT_TOKEN=root-token-dev'"
  echo "- Voor productie: gebruik de root token die je kreeg bij 'vault operator init'"
  exit 1
fi

# Verwerk command line argumenten
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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

# Controleer of USERNAME is opgegeven
if [ -z "$USERNAME" ]; then
  echo "FOUT: Gebruikersnaam is verplicht"
  show_help
fi

# Vraag om wachtwoord als het niet is opgegeven
if [ -z "$PASSWORD" ]; then
  echo -n "Voer wachtwoord in voor gebruiker $USERNAME: "
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

echo "OpenBAO globale admin aanmaken: $USERNAME"
echo "================================================"

# Controleer of OpenBAO bereikbaar is
echo "Controleren of OpenBAO bereikbaar is..."
if ! vault status > /dev/null 2>&1; then
  echo "FOUT: Kan geen verbinding maken met OpenBAO op $VAULT_ADDR"
  echo "Zorg ervoor dat OpenBAO draait en bereikbaar is."
  exit 1
fi

# Userpass authenticatie inschakelen als het nog niet is ingeschakeld
echo -e "\nUserpass authenticatie inschakelen..."
if ! vault auth list | grep -q "^userpass/"; then
  vault auth enable userpass
  echo "Userpass authenticatie ingeschakeld."
else
  echo "Userpass authenticatie is al ingeschakeld."
fi

# Admin policy aanmaken
echo -e "\nAdmin policy aanmaken..."
cat > /tmp/admin-policy.hcl << EOF
# Admin policy voor globale beheerder
# Geeft volledige toegang tot het systeem, behalve voor root-only operaties

# Systeembeheer
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Namespace beheer
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Auth methodes beheren
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Secrets engines beheren
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Policies beheren
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Toegang tot alle secrets
path "+/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

vault policy write admin /tmp/admin-policy.hcl
echo "Admin policy aangemaakt."

# Admin gebruiker aanmaken
echo -e "\nAdmin gebruiker aanmaken..."
vault write auth/userpass/users/$USERNAME \
  password="$PASSWORD" \
  policies=admin

echo -e "\n================================================"
echo "Globale admin gebruiker is succesvol aangemaakt!"
echo "================================================"
echo "Gebruikersnaam: $USERNAME"
echo "Policy: admin"
echo "================================================"
echo -e "\nJe kunt nu inloggen met:"
echo "vault login -method=userpass username=$USERNAME"
echo -e "\nHet wordt aanbevolen om de root token te revoken na het testen van deze admin gebruiker:"
echo "vault token revoke -self"
echo "================================================"
