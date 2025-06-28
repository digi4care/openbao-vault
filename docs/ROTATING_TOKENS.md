# Token Rotatie in OpenBAO

Dit document legt uit hoe token rotatie werkt in OpenBAO en hoe je het `rotate_tokens.sh` script kunt gebruiken om je beveiligingsposture te verbeteren.

## Wat is token rotatie?

In OpenBAO/Vault worden tokens gebruikt om toegang te krijgen tot geheimen en resources. Een token is een soort tijdelijk wachtwoord dat toegang geeft tot specifieke resources op basis van de gekoppelde policies.

Het probleem met permanente tokens of tokens met een zeer lange levensduur is dat ze een significant beveiligingsrisico vormen als ze worden gestolen, gelekt of gecompromitteerd. Als een aanvaller toegang krijgt tot een permanent token, hebben ze potentieel voor onbeperkte tijd toegang tot gevoelige gegevens.

Token rotatie is een beveiligingspraktijk waarbij tokens regelmatig worden vervangen door nieuwe tokens met een beperkte levensduur. Dit beperkt de schade die kan worden aangericht als een token wordt gecompromitteerd.

## Hoe werkt het `rotate_tokens.sh` script?

Het `rotate_tokens.sh` script automatiseert het proces van token rotatie en implementeert best practices voor token lifecycle management. Het script doet het volgende:

1. **Maakt korte-termijn tokens**: In plaats van een token te gebruiken dat voor altijd geldig is, maakt dit script tokens die automatisch verlopen na een bepaalde tijd (TTL - Time To Live).

2. **Stelt een maximale levensduur in**: Zelfs als je het token verlengt (renews), zal het uiteindelijk definitief verlopen na de maximale levensduur (max TTL).

3. **Koppelt tokens aan specifieke policies**: Het token krijgt alleen de rechten die het nodig heeft, volgens het principe van least privilege.

4. **Slaat tokens veilig op**: Het script slaat de nieuwe tokens op in bestanden die je kunt gebruiken in je applicaties of scripts.

5. **Ondersteunt verschillende authenticatiemethoden**: Het script werkt zowel met userpass authenticatie (voor menselijke gebruikers) als met AppRole authenticatie (voor services en applicaties).

## Praktische voorbeelden

### Voor menselijke gebruikers (userpass authenticatie)

Stel je hebt een global admin account en je wilt veilig werken:

```bash
./run_in_container.sh rotate_tokens.sh -u admin.user -t 1h -m 24h -p admin
```

Dit geeft je een token dat:

- 1 uur geldig is (`-t 1h`)
- Maximaal 24 uur kan worden verlengd (`-m 24h`)
- De admin policy heeft (`-p admin`)

Je gebruikt dit token voor je werkzaamheden in plaats van steeds je wachtwoord in te voeren. Na 1 uur moet het token worden verlengd (renewal), wat automatisch kan gebeuren als je applicatie dat ondersteunt. Na 24 uur verloopt het token definitief en moet je een nieuw token aanmaken.

### Voor services (AppRole authenticatie)

Voor geautomatiseerde processen en applicaties:

```bash
./run_in_container.sh rotate_tokens.sh -r payment-service -t 1h -p payment-service-policy
```

Dit maakt een token voor de payment-service AppRole met dezelfde beperkingen qua levensduur.

## Waarom is token rotatie belangrijk?

1. **Beperkte schade bij diefstal**: Als iemand je token steelt, hebben ze maximaal de TTL of max TTL toegang, niet voor altijd.

2. **Automatische intrekking**: Je hoeft tokens niet handmatig in te trekken; ze verlopen vanzelf na de ingestelde periode.

3. **Audit trail**: Elk token laat sporen na in de audit logs, zodat je kunt zien wie wat heeft gedaan en wanneer.

4. **Geen wachtwoorden opslaan**: Applicaties hoeven geen wachtwoorden op te slaan, alleen korte-termijn tokens die regelmatig worden ververst.

5. **Compliance**: Veel beveiligingsstandaarden en compliance frameworks (zoals PCI DSS, SOC2, ISO 27001) vereisen regelmatige rotatie van credentials.

## Best practices voor token rotatie

1. **Gebruik korte TTL's**: Hoe korter de levensduur van een token, hoe veiliger. Voor interactieve sessies is 1-4 uur meestal voldoende.

2. **Implementeer automatische verlenging**: Voor langere sessies, implementeer automatische token verlenging (renewal) in je applicaties.

3. **Beperk de maximale levensduur**: Zelfs met verlenging moet een token uiteindelijk verlopen. Een max TTL van 24-72 uur is gebruikelijk.

4. **Gebruik verschillende tokens voor verschillende doeleinden**: Maak aparte tokens voor verschillende applicaties of functies, elk met hun eigen specifieke policies.

5. **Sla tokens veilig op**: Behandel tokens als gevoelige gegevens en sla ze veilig op, bijvoorbeeld in een secrets manager of als environment variabelen.

6. **Roteer regelmatig**: Implementeer een schema voor regelmatige token rotatie, zelfs voordat tokens verlopen.

## Integratie met CI/CD en automatisering

Voor productieomgevingen is het aan te raden om token rotatie te integreren in je CI/CD pipeline of automatiseringsprocessen:

1. **Scheduled jobs**: Gebruik cron jobs of scheduled tasks om regelmatig nieuwe tokens te genereren.

2. **Secrets management**: Integreer met een secrets manager zoals HashiCorp Vault zelf, AWS Secrets Manager, of Azure Key Vault om tokens veilig op te slaan en te distribueren.

3. **Monitoring**: Implementeer monitoring om te waarschuwen wanneer tokens bijna verlopen of wanneer er ongebruikelijke tokenactiviteit is.

## Conclusie

Token rotatie is een essentiële beveiligingspraktijk voor elke OpenBAO/Vault implementatie. Door regelmatig tokens te verversen en hun levensduur te beperken, verminder je aanzienlijk het risico van ongeautoriseerde toegang tot je geheimen en systemen.

Het `rotate_tokens.sh` script maakt het eenvoudig om deze best practice te implementeren in je omgeving, of je nu een enkele admin bent of een groot team met vele services en applicaties.
