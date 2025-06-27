#!/bin/bash

# Script om gegevens van een klant toe te voegen aan Vault
# Gebruik: ./set_client_data.sh klantnaam pad sleutel waarde
# Bijvoorbeeld: ./set_client_data.sh klant123 api-keys wordpress "mijn-api-key"

# Controleer of er voldoende parameters zijn opgegeven
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  echo "Gebruik: $0 <klantnaam> <pad> <sleutel> <waarde>"
  echo "Bijvoorbeeld: $0 klant123 api-keys wordpress mijn-api-key"
  exit 1
fi

KLANT_ID="$1"
PAD="$2"
SLEUTEL="$3"
WAARDE="$4"

# Controleer of we verbinding kunnen maken met Vault
if ! vault status > /dev/null 2>&1; then
  echo "Kan geen verbinding maken met Vault. Zorg ervoor dat Vault draait en dat je bent ingelogd."
  exit 1
fi

# Haal de huidige gegevens op (als ze bestaan)
if vault kv get secret/klanten/$KLANT_ID/$PAD &>/dev/null; then
  # Voeg de nieuwe sleutel toe aan bestaande gegevens
  echo "Bestaande gegevens bijwerken..."
  vault kv patch secret/klanten/$KLANT_ID/$PAD $SLEUTEL="$WAARDE"
else
  # Maak een nieuw geheim aan
  echo "Nieuw geheim aanmaken..."
  vault kv put secret/klanten/$KLANT_ID/$PAD $SLEUTEL="$WAARDE"
fi

echo "Gegevens succesvol opgeslagen voor klant $KLANT_ID!"
echo "Pad: secret/klanten/$KLANT_ID/$PAD"
echo "Sleutel: $SLEUTEL"
