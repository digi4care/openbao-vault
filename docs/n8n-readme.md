# Vault gegevens opvragen via n8n

Eenvoudige handleiding voor het opvragen van klantgegevens uit Vault via n8n.

## Wat heb je nodig

- Een token voor Vault (vraag deze aan de beheerder)
- Toegang tot n8n

## Stap 1: HTTP Request node instellen

1. Open n8n en maak een nieuwe workflow
2. Voeg een HTTP Request node toe
3. Configureer de node als volgt:

![HTTP Request node configuratie](https://i.imgur.com/example.png)

### Instellingen:

- **Method**: GET
- **URL**: `https://vault.hummer.ai:49281/v1/secret/data/klanten/KLANTNAAM/GEGEVENSPAD`
  - Vervang `KLANTNAAM` met de naam van de klant (bijv. `klant123`)
  - Vervang `GEGEVENSPAD` met het pad naar de gegevens (bijv. `api-keys`)
- **Headers**:
  - Naam: `X-Vault-Token`
  - Waarde: `JOUW-TOKEN` (vervang met je eigen Vault token)

## Stap 2: Gegevens verwerken

De gegevens komen terug in dit formaat:

```json
{
  "data": {
    "data": {
      "sleutel1": "waarde1",
      "sleutel2": "waarde2"
    }
  }
}
```

Om de gegevens te gebruiken in een volgende node:

- Gebruik `{{$node["HTTP Request"].json.data.data.sleutel1}}` om een specifieke waarde te krijgen
- Of gebruik `{{$node["HTTP Request"].json.data.data}}` om alle gegevens te krijgen

## Voorbeelden

### Voorbeeld 1: API key ophalen

- **URL**: `https://vault.hummer.ai:49281/v1/secret/data/klanten/klant123/api-keys`
- In een volgende node: `{{$node["HTTP Request"].json.data.data.wordpress}}`

### Voorbeeld 2: Database credentials ophalen

- **URL**: `https://vault.hummer.ai:49281/v1/secret/data/klanten/klant123/database`
- In een volgende node: `{{$node["HTTP Request"].json.data.data.password}}`

## Troubleshooting

- **403 Forbidden**: Controleer of je token geldig is en de juiste rechten heeft
- **404 Not Found**: Controleer of het pad naar de gegevens correct is
- **Empty response**: Controleer of er daadwerkelijk gegevens zijn opgeslagen op dat pad
