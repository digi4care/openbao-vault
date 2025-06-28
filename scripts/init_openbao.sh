#!/bin/bash
# Script om de status van OpenBAO te controleren
# Vooral nuttig in productieomgeving, in ontwikkelomgeving is OpenBAO direct klaar voor gebruik
# Auteur: Chris Engelhard <chris@chrisengelhard.nl>
# Datum: 2025-06-28

set -e

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}

# In productie moet je de root token gebruiken die je krijgt bij het initialiseren
# In ontwikkeling moet je de root token uit de container logs halen
if [ -z "$VAULT_TOKEN" ]; then
  echo "WAARSCHUWING: Geen VAULT_TOKEN opgegeven."
  echo "- Voor ontwikkeling: haal de root token op met 'docker logs openbao-dev | grep "Root Token"'"
  echo "  en gebruik dan 'export VAULT_TOKEN=<token-from-logs>'"
  echo "- Voor productie: gebruik de root token die je kreeg bij 'vault operator init'"
  exit 1
fi

echo "OpenBAO status controle script"
echo "============================"
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

echo -e "\n================================================"
echo "OpenBAO is bereikbaar en klaar voor gebruik!"
echo "================================================"
echo "Je kunt nu het create_namespace.sh script uitvoeren om"
echo "de namespace en authenticatie voor te bereiden:"
echo "./scripts/create_namespace.sh --namespace <namespace>"
echo "================================================"
