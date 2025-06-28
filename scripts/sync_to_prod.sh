#!/bin/bash
# Script om klantgegevens van lokale Vault naar productie Vault te synchroniseren

# Configuratie
LOCAL_VAULT="http://127.0.0.1:49281"
PROD_VAULT="https://vault.hummer.ai:49281"
LOCAL_TOKEN="root-token-dev"
PROD_TOKEN="jouw-productie-token" # Vervang dit met je echte productie token

# Controleer of jq is geïnstalleerd
if ! command -v jq &> /dev/null; then
    echo "jq is niet geïnstalleerd. Installeer het met: sudo apt-get install jq"
    exit 1
fi

# Functie om een secret te kopiëren van lokaal naar productie
sync_secret() {
    local path=$1
    echo "Synchroniseren van $path..."
    
    # Haal gegevens op van lokale Vault
    local data=$(curl -s -H "X-Vault-Token: $LOCAL_TOKEN" "$LOCAL_VAULT/v1/secret/data/$path")
    
    # Controleer of we gegevens hebben ontvangen
    if [ "$(echo $data | jq -r '.data')" == "null" ]; then
        echo "Geen gegevens gevonden op pad $path"
        return
    fi
    
    # Extraheer alleen de data die we nodig hebben
    local secret_data=$(echo $data | jq -r '.data.data')
    
    # Schrijf naar productie Vault
    curl -s -H "X-Vault-Token: $PROD_TOKEN" -H "Content-Type: application/json" \
        -X POST -d "{\"data\": $secret_data}" \
        "$PROD_VAULT/v1/secret/data/$path" > /dev/null
    
    echo "✓ $path gesynchroniseerd"
}

# Functie om alle klanten op te halen
get_clients() {
    # Haal alle klanten op (mappen onder 'klanten/')
    local clients=$(curl -s -H "X-Vault-Token: $LOCAL_TOKEN" "$LOCAL_VAULT/v1/secret/metadata/klanten/" | jq -r '.data.keys[]')
    echo "$clients"
}

# Functie om alle gegevenspaden voor een klant op te halen
get_client_paths() {
    local client=$1
    # Haal alle paden op voor deze klant
    local paths=$(curl -s -H "X-Vault-Token: $LOCAL_TOKEN" "$LOCAL_VAULT/v1/secret/metadata/klanten/$client/" | jq -r '.data.keys[]')
    echo "$paths"
}

# Hoofdfunctie
main() {
    echo "Start synchronisatie van lokale Vault naar productie Vault..."
    
    # Haal alle klanten op
    clients=$(get_clients)
    
    # Voor elke klant
    for client in $clients; do
        echo "Verwerken van klant: $client"
        
        # Haal alle paden op voor deze klant
        paths=$(get_client_paths "$client")
        
        # Voor elk pad
        for path in $paths; do
            sync_secret "klanten/$client/$path"
        done
    done
    
    echo "Synchronisatie voltooid!"
}

# Voer het script uit
main
