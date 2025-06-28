# OpenBAO Handleiding: Tokens, Opstarten en Scripts

Deze handleiding legt uit hoe OpenBAO werkt, zowel in de ontwikkel- als productieomgeving, met focus op tokens, opstarten en het gebruik van scripts.

## Inhoudsopgave

- [Ontwikkelomgeving vs. Productieomgeving](#ontwikkelomgeving-vs-productieomgeving)
- [Beschikbare Scripts](#beschikbare-scripts)
- [Tokens in Ontwikkelomgeving](#tokens-in-ontwikkelomgeving)
- [Tokens in Productieomgeving](#tokens-in-productieomgeving)
- [Gebruikersbeheer](#gebruikersbeheer)
  - [Gebruikersrollen](#gebruikersrollen)
  - [Admin Aanmaken](#admin-aanmaken)
  - [Client Operators Aanmaken](#client-operators-aanmaken)
- [Stap-voor-stap: Eerste Keer Opstarten](#stap-voor-stap-eerste-keer-opstarten)
  - [In Ontwikkeling](#in-ontwikkeling)
  - [In Productie](#in-productie)
- [Stap-voor-stap: Herstart in Productie](#stap-voor-stap-herstart-in-productie)
- [Veelgestelde Vragen](#veelgestelde-vragen)

## Ontwikkelomgeving vs. Productieomgeving

### Ontwikkelomgeving

- **Opslagtype**: In-memory (tijdelijk)
- **Beveiliging**: Minimaal (voor gemak van ontwikkeling)
- **Opstarten**: Automatisch, geen handmatige stappen nodig
- **Data persistentie**: Geen, alles verdwijnt bij herstart
- **Root Token**: Standaard `root-token-dev` (ingesteld in `.env.vault.dev`)

### Productieomgeving

- **Opslagtype**: Persistent op schijf
- **Beveiliging**: Maximaal (sealed/unsealed concept)
- **Opstarten**: Handmatige stappen vereist
- **Data persistentie**: Volledig, alles blijft bewaard
- **Root Token**: Gegenereerd bij initialisatie, moet veilig bewaard worden

## Beschikbare Scripts

### init_openbao.sh

Dit script controleert of OpenBAO bereikbaar is en toont de status. Het is de eerste stap in het opzetten van OpenBAO.

### prepare_namespace.sh

Dit script bereidt een namespace voor door:

- Een namespace aan te maken
- KV secrets engine in te schakelen
- AppRole authenticatie te configureren
- Policies aan te maken
- Role ID en Secret ID te genereren voor de namespace

Gebruik:

```bash
./scripts/prepare_namespace.sh --namespace [naam] --path [pad] --role [rol] --ttl [tijd]
```

### add_client.sh

Dit script voegt een nieuwe klant toe aan OpenBAO met de juiste secrets.

### create_admin.sh

Dit script maakt een globale admin gebruiker aan die alle namespaces kan beheren. Deze admin vervangt de root token voor dagelijks gebruik.

### create_operator.sh

Dit script maakt per client een operator aan die alleen de secrets van die specifieke client kan beheren.

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

## Gebruikersbeheer

### Gebruikersrollen

OpenBAO gebruikt een hiërarchie van gebruikersrollen voor veilig beheer:

1. **Root Token**

   - Hoogste niveau van toegang
   - Alleen gebruiken voor initiële setup en noodgevallen
   - Moet worden ingetrokken (revoked) na gebruik
   - Heeft toegang tot alle functies en data

2. **Admin**

   - Globale beheerder die alle namespaces kan beheren
   - Kan namespaces, auth methodes en policies aanmaken
   - Vervangt de root token voor dagelijks beheer
   - Aangemaakt via `create_admin.sh`

3. **Operators**

   - Per client/namespace een operator
   - Kan alleen de secrets van die specifieke client beheren
   - Heeft geen toegang tot systeeminstellingen of andere clients
   - Aangemaakt via `create_operator.sh`

4. **AppRole**
   - Voor applicaties zoals n8n
   - Alleen leesrechten voor specifieke secrets
   - Korte levensduur tokens
   - Aangemaakt via `prepare_namespace.sh`

### Admin Aanmaken

Gebruik het `create_admin.sh` script om een globale admin aan te maken:

```bash
./scripts/create_admin.sh --username admin
```

De admin krijgt volledige rechten om:

- Namespaces te beheren
- Auth methodes te configureren
- Secrets engines te beheren
- Policies aan te maken
- Toegang tot alle secrets

Na het aanmaken van een admin kun je ervoor kiezen om de root token in te trekken voor betere beveiliging:

```bash
vault token revoke -self
```

**Let op**: Als je de root token intrekt, kun je niet meer inloggen als root. In noodgevallen kun je altijd een nieuwe root token genereren met behulp van de unseal keys:

```bash
vault operator generate-root -init
# Volg de instructies en gebruik minimaal 3 unseal keys
```

### Client Operators Aanmaken

Gebruik het `create_operator.sh` script om per client een operator aan te maken:

```bash
./scripts/create_operator.sh --namespace digi4care --client klant123 --username klant123-operator
```

De operator krijgt beperkte rechten:

- Volledige toegang tot de secrets van alleen die specifieke client
- Alleen leesrechten voor de client lijst
- Geen toegang tot andere clients of systeeminstellingen

Operators kunnen inloggen met:

```bash
export VAULT_NAMESPACE=digi4care
vault login -method=userpass username=klant123-operator
```

## Stap-voor-stap: Eerste Keer Opstarten

### In Ontwikkeling

```bash
# Start de container
docker compose -f docker-compose.dev.yml up -d

# Stel de root token in
export VAULT_TOKEN=root-token-dev

# Initialiseer OpenBAO
./scripts/init_openbao.sh

# Bereid de n8n namespace voor
./scripts/prepare_n8n.sh
```

### In Productie

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

6. **Verlaat de container**:

   ```bash
   exit
   ```

7. **Stel de root token in voor de scripts**:

   ```bash
   export VAULT_TOKEN=[Root Token]
   ```

8. **Voer de scripts uit**:

   ```bash
   ./scripts/init_openbao.sh
   ./scripts/prepare_n8n.sh
   ```

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

### Wat is het verschil tussen een root token en een gewone token?

Een root token heeft onbeperkte toegang tot alle functies en data in OpenBAO. Een gewone token heeft alleen toegang tot specifieke paden en functies, gebaseerd op de toegewezen policies.

### Hoe lang blijft een token geldig?

In de ontwikkelomgeving: tot de container herstart wordt.
In productie: tot de token wordt ingetrokken of verloopt (als er een TTL is ingesteld).

### Wat gebeurt er als ik mijn root token kwijtraak?

In ontwikkeling: start de container opnieuw en gebruik de nieuwe token uit de logs.
In productie: gebruik de unseal keys om een nieuwe root token te genereren met `vault operator generate-root`.

### Moet ik OpenBAO elke keer unsealen na een herstart?

Ja, in de productieomgeving moet je OpenBAO na elke herstart unsealen met minimaal 3 van de 5 unseal keys.

### Kan ik het unsealen automatiseren?

Technisch gezien wel, maar dit wordt afgeraden vanuit beveiligingsoogpunt. Het doel van sealing is juist om handmatige interventie te vereisen bij een herstart.

### Wat is het verschil tussen een admin en een operator?

Een admin heeft globale rechten om het hele systeem te beheren, inclusief alle namespaces. Een operator heeft alleen rechten om de secrets van één specifieke client te beheren binnen een namespace.

### Moet ik de root token intrekken na gebruik?

Het is een goede beveiligingspraktijk om de root token in te trekken na het aanmaken van een admin gebruiker, maar dit is niet verplicht. Bedenk wel dat:

- Als je de root token intrekt, kun je niet meer inloggen als root
- Je kunt altijd een nieuwe root token genereren met `vault operator generate-root` en je unseal keys
- De admin kan alle dagelijkse beheertaken uitvoeren zonder het beveiligingsrisico van een actieve root token

### Hoe kan een client operator inloggen?

Een client operator moet eerst de namespace instellen en kan dan inloggen met de userpass methode:

````bash
export VAULT_NAMESPACE=digi4care
vault login -method=userpass username=klant123-operator
``` cloud KMS-diensten of HashiCorp's Transit secrets engine.

### Wat is het verschil tussen "sealed" en "unsealed"?

- **Sealed**: OpenBAO is vergrendeld, de encryptiesleutel is niet in het geheugen, geen toegang tot data
- **Unsealed**: OpenBAO is ontgrendeld, de encryptiesleutel is in het geheugen geladen, data is toegankelijk
### Hoeveel unseal keys heb ik nodig?

Standaard genereert OpenBAO 5 keys, waarvan je er 3 nodig hebt om te unsealen (dit heet "Shamir's Secret Sharing"). Je kunt dit aanpassen tijdens initialisatie.
````
