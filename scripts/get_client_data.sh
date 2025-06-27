#!/bin/bash

# Script om gegevens van een klant op te vragen uit Vault
# Gebruik: ./get_client_data.sh klantnaam pad [veld]
# Bijvoorbeeld: ./get_client_data.sh klant123 api-keys
# Of: ./get_client_data.sh klant123 api-keys wordpress

# Controleer of er voldoende parameters zijn opgegeven
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Gebruik: $0 <klantnaam> <pad> [veld]"
  echo "Bijvoorbeeld: $0 klant123 api-keys"
  echo "Of: $0 klant123 api-keys wordpress"
  exit 1
fi

KLANT_ID="$1"
PAD="$2"
VELD="$3"

# Controleer of we verbinding kunnen maken met Vault
if ! vault status > /dev/null 2>&1; then
  echo "Kan geen verbinding maken met Vault. Zorg ervoor dat Vault draait en dat je bent ingelogd."
  exit 1
fi

# Haal de gegevens op
if [ -z "$VELD" ]; then
  # Haal alle gegevens op als er geen veld is opgegeven
  vault kv get secret/klanten/$KLANT_ID/$PAD
else
  # Haal alleen het opgegeven veld op
  vault kv get -field=$VELD secret/klanten/$KLANT_ID/$PAD
fi
