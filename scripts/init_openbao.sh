#!/bin/bash
# Script voor initiële setup van OpenBAO
# Auteur: Chris Engelhard <chris@chrisengelhard.nl>
# Datum: 2025-06-28

set -e

# Configuratie
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}

# In productie moet je de root token gebruiken die je krijgt bij het initialiseren
# In ontwikkeling kun je de standaard root token gebruiken
if [ -z "$VAULT_TOKEN" ]; then
  echo "WAARSCHUWING: Geen VAULT_TOKEN opgegeven."
  echo "- Voor ontwikkeling: gebruik 'export VAULT_TOKEN=root-token-dev'"
  echo "- Voor productie: gebruik de root token die je kreeg bij 'vault operator init'"
  exit 1
fi

echo "OpenBAO initialisatie script"
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
echo "OpenBAO is succesvol geïnitialiseerd!"
echo "================================================"
echo "Je kunt nu het prepare_namespace.sh script uitvoeren om"
echo "de namespace en authenticatie voor te bereiden."
echo "================================================"
