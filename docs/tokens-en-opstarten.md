# OpenBAO Tokens en Opstarten: Een Eenvoudige Uitleg

Dit document legt uit hoe tokens en het opstarten van OpenBAO werken, zowel in de ontwikkel- als productieomgeving.

## Inhoudsopgave

- [Ontwikkelomgeving vs. Productieomgeving](#ontwikkelomgeving-vs-productieomgeving)
- [Tokens in Ontwikkelomgeving](#tokens-in-ontwikkelomgeving)
- [Tokens in Productieomgeving](#tokens-in-productieomgeving)
- [Stap-voor-stap: Eerste Keer Opstarten in Productie](#stap-voor-stap-eerste-keer-opstarten-in-productie)
- [Stap-voor-stap: Herstart in Productie](#stap-voor-stap-herstart-in-productie)
- [Veelgestelde Vragen](#veelgestelde-vragen)

## Ontwikkelomgeving vs. Productieomgeving

### Ontwikkelomgeving

- **Opslagtype**: In-memory (tijdelijk)
- **Beveiliging**: Minimaal (voor gemak van ontwikkeling)
- **Opstarten**: Automatisch, geen handmatige stappen nodig
- **Data persistentie**: Geen, alles verdwijnt bij herstart

### Productieomgeving

- **Opslagtype**: Persistent op schijf
- **Beveiliging**: Maximaal (sealed/unsealed concept)
- **Opstarten**: Handmatige stappen vereist
- **Data persistentie**: Volledig, alles blijft bewaard

## Tokens in Ontwikkelomgeving

In de ontwikkelomgeving (dev-mode):

1. **Bij elke start**: OpenBAO genereert een nieuwe root token, zelfs als je `VAULT_DEV_ROOT_TOKEN_ID` hebt ingesteld
2. **Waarom?**: Dev-mode is ontworpen voor tijdelijk gebruik en draait volledig in-memory
3. **Waar te vinden**: De nieuwe token wordt getoond in de logs:

   ```text
   Root Token: s.hpDzvvp3AHLs4XfIKMv6si35
   ```

4. **Gebruik**: Je moet deze token gebruiken voor alle operaties, of hem exporteren:

   ```bash
   export VAULT_TOKEN=s.hpDzvvp3AHLs4XfIKMv6si35
   ```

## Tokens in Productieomgeving

In de productieomgeving:

1. **Eerste initialisatie**: Je krijgt één keer een root token bij het initialiseren
2. **Bij herstart**: De token blijft hetzelfde, maar OpenBAO is "sealed" (vergrendeld)
3. **Persistentie**: De token blijft geldig totdat je hem intrekt of vernieuwt
4. **Veiligheid**: De root token heeft volledige toegang, gebruik deze alleen voor initiële setup

## Stap-voor-stap: Eerste Keer Opstarten in Productie

Wanneer je OpenBAO voor het eerst in productie start:

1. **Start de container**:

   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```

2. **Initialiseer OpenBAO** (dit doe je maar één keer):

   ```bash
   docker exec -it vault-prod sh
   vault operator init
   ```

3. **Bewaar de output veilig!** Je krijgt:

   - 5 unseal keys (standaard)
   - 1 root token

   Bijvoorbeeld:

   ```text
   Unseal Key 1: a3EfGhIjK4lMnOpQrStUvWxYz0123456789ABCDEFG
   Unseal Key 2: bCdEfGhIjK4lMnOpQrStUvWxYz0123456789ABCDEF
   Unseal Key 3: cDeFgHiJkL4mNoPqRsTuVwXyZ0123456789ABCDE
   Unseal Key 4: dEfGhIjKlM4nOpQrStUvWxYz0123456789ABCDE
   Unseal Key 5: eFgHiJkLmN4oPqRsTuVwXyZ0123456789ABCD

   Root Token: hvs.UvWxYz0123456789ABCDEFGhIjKlMnOpQrSt
   ```

4. **Unseal OpenBAO** (gebruik 3 van de 5 keys):

   ```bash
   vault operator unseal [Unseal Key 1]
   vault operator unseal [Unseal Key 2]
   vault operator unseal [Unseal Key 3]
   ```

5. **Log in met de root token**:

   ```bash
   vault login [Root Token]
   ```

6. **Stel alles in** (namespaces, policies, etc.)

## Stap-voor-stap: Herstart in Productie

Wanneer je de productiecontainer herstart:

1. **OpenBAO is sealed**: Na herstart is OpenBAO vergrendeld
2. **Unseal nodig**: Je moet het handmatig ontgrendelen met de unseal keys

   ```bash
   docker exec -it vault-prod sh
   vault operator unseal [Unseal Key 1]
   vault operator unseal [Unseal Key 2]
   vault operator unseal [Unseal Key 3]
   ```

3. **Log in**: Gebruik dezelfde root token als bij initialisatie

   ```bash
   vault login [Root Token]
   ```

## Veelgestelde Vragen

### Waarom krijg ik steeds een nieuwe token in ontwikkeling?

Dev-mode is ontworpen voor tijdelijk gebruik en reset alles bij elke start. Dit is normaal gedrag.

### Wat als ik mijn unseal keys kwijtraak?

Zonder unseal keys kun je niet meer bij je data. Er is geen "reset" of "wachtwoord vergeten" functie. Bewaar deze keys op meerdere veilige locaties.

### Moet ik de root token blijven gebruiken?

Nee, voor dagelijks gebruik is het beter om AppRole of een andere authenticatiemethode te gebruiken. De root token is alleen voor initiële setup en noodgevallen.

### Kan ik het unsealen automatiseren?

Ja, maar dit vermindert de veiligheid. Auto-unseal kan worden geconfigureerd met cloud KMS-diensten of HashiCorp's Transit secrets engine.

### Wat is het verschil tussen "sealed" en "unsealed"?

- **Sealed**: OpenBAO is vergrendeld, de encryptiesleutel is niet in het geheugen, geen toegang tot data
- **Unsealed**: OpenBAO is ontgrendeld, de encryptiesleutel is in het geheugen geladen, data is toegankelijk

### Hoeveel unseal keys heb ik nodig?

Standaard genereert OpenBAO 5 keys, waarvan je er 3 nodig hebt om te unsealen (dit heet "Shamir's Secret Sharing"). Je kunt dit aanpassen tijdens initialisatie.
