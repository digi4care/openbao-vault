# OpenBAO gegevens opvragen via n8n

Eenvoudige handleiding voor het opvragen van klantgegevens uit OpenBAO via n8n.

## Wat heb je nodig

- AppRole credentials voor OpenBAO (Role ID en Secret ID)
- Toegang tot n8n

## Stap 1: Vault node instellen

1. Open n8n en maak een nieuwe workflow
2. Voeg een Vault node toe (of gebruik HTTP Request als alternatief)
3. Configureer de node als volgt:

### Vault Node Instellingen:

- **URL**: `https://vault.hummer.ai/v1`
- **Auth Method**: AppRole
- **Role ID**: `JOUW-ROLE-ID` (vraag deze aan de beheerder)
- **Secret ID**: `JOUW-SECRET-ID` (vraag deze aan de beheerder)
- **Namespace**: `n8n`
- **Path**: `clients/{{$json["klant_id"]}}/api-keys`

### Alternatief met HTTP Request Node:

- **Method**: GET
- **URL**: `https://vault.hummer.ai/v1/clients/data/KLANTNAAM/GEGEVENSPAD`
  - Vervang `KLANTNAAM` met de naam van de klant (bijv. `klant123`)
  - Vervang `GEGEVENSPAD` met het pad naar de gegevens (bijv. `api-keys`)
- **Authentication**: AppRole (VERPLICHT)
  - Role ID: `JOUW-ROLE-ID`
  - Secret ID: `JOUW-SECRET-ID`
- **Headers**:
  - Naam: `X-Vault-Namespace`
  - Waarde: `n8n`

> **BELANGRIJK**: Alleen de URL kennen is NIET voldoende om toegang te krijgen tot de gegevens. OpenBAO vereist geldige authenticatie (Role ID + Secret ID) én de juiste autorisatie via policies. Zonder deze credentials worden alle verzoeken geweigerd, ongeacht of de URL correct is.

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
