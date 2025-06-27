# 🔐 HashiCorp Vault Setup

HashiCorp Vault setup met Docker voor veilige opslag van gevoelige gegevens voor verschillende klanten. Deze setup bevat zowel een ontwikkel- als een productieomgeving.

## ✨ Functies

- 🐳 Draait in een Docker container
- 🔒 TLS encryptie voor productie, eenvoudige setup voor ontwikkeling
- 📦 Eenvoudige bestandsopslag (geen cluster nodig)
- 🔑 Authenticatie met root token
- 🛡️ Beperkte toegang via poort 49281 om fingerprinting tegen te gaan
- 🌐 Productieomgeving op vault.hummer.ai, ontwikkelomgeving op lokale machine

## 🚀 Snelstart

1. **Kloon de repository**

   ```bash
   git clone [repository-url]
   cd hashicorp-vault
   ```

2. **Kies je omgeving**

   ### Ontwikkelomgeving (Zonder TLS)

   ```bash
   # Maak de benodigde mappen aan als ze nog niet bestaan
   mkdir -p vault/data vault/config

   # Start Vault in ontwikkelmodus
   docker-compose -f docker-compose.dev.yml up -d
   ```

   ### Productieomgeving (Met TLS)

   ```bash
   # Maak de benodigde mappen aan als ze nog niet bestaan
   mkdir -p vault/data vault/config vault/tls

   # Zorg dat je TLS certificaten hebt (zie sectie "Certificaten aanmaken")
   # Start Vault in productiemodus
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. **Open de webinterface**
   - Ontwikkeling: Ga naar: [http://localhost:49281](http://localhost:49281)
     - Gebruik token: `root-token-dev` (zoals geconfigureerd in .env.vault.dev)
   - Productie: https://vault.hummer.ai:49281
     - Gebruik de root token die je krijgt na initialisatie (zie sectie "Initialiseer Vault")

## 📜 Certificaten aanmaken (Optioneel, voor productie)

### Optie 1: Zelfondertekend certificaat met OpenSSL

1. **Installeer OpenSSL** (indien nodig):

   ```bash
   sudo apt-get update && sudo apt-get install -y openssl
   ```

2. **Maak een map voor certificaten**

   ```bash
   mkdir -p vault/tls
   cd vault/tls
   ```

3. **Genereer een Ed25519 private key**

   ```bash
   # Controleer eerst of je OpenSSL 1.1.1 of hoger hebt
   openssl version

   # Genereer een Ed25519 private key
   openssl genpkey -algorithm ed25519 -out privkey.pem

   # Optioneel: Converteer naar het juiste formaat als dat nodig is
   # openssl pkey -in privkey.pem -out privkey.pem -traditional
   ```

4. **Maak een Certificate Signing Request (CSR)**

   ```bash
   openssl req -new -key privkey.pem -out csr.pem -subj "/CN=vault.hummer.ai"
   ```

5. **Genereer een zelfondertekend certificaat**

   ```bash
   openssl req -x509 -key privkey.pem -in csr.pem -out fullchain.pem -days 365
   ```

6. **Zet de juiste permissies**

   ```bash
   chmod 600 privkey.pem fullchain.pem
   ```

### Optie 2: Gebruik Let's Encrypt (Aanbevolen voor productie)

1. Installeer certbot:

   ```bash
   sudo apt-get update
   sudo apt-get install -y certbot
   ```

2. Vraag een certificaat aan (vervang je e-mail en domein):

   ```bash
   sudo certbot certonly --standalone -d vault.hummer.ai --email admin@example.com --agree-tos --non-interactive
   ```

3. Kopieer de certificaten:

   ```bash
   sudo cp /etc/letsencrypt/live/vault.hummer.ai/privkey.pem vault/tls/
   sudo cp /etc/letsencrypt/live/vault.hummer.ai/fullchain.pem vault/tls/
   sudo chown $USER:$USER vault/tls/*.pem
   ```

### Automatisch verniewen van Let's Encrypt certificaten

Voeg een cronjob toe om de certificaten automatisch te verniewen:

1. Maak een vernieuwingsscript:

   ```bash
   sudo nano /usr/local/bin/renew_vault_certs.sh
   ```

2. Voeg dit toe aan het bestand (pas paden aan indien nodig):

   ```bash
   #!/bin/bash

   # Vernieuw certificaten
   /usr/bin/certbot renew --quiet --deploy-hook "
     # Kopieer nieuwe certificaten
     cp /etc/letsencrypt/live/vault.hummer.ai/privkey.pem /pad/naar/vault/tls/
     cp /etc/letsencrypt/live/vault.hummer.ai/fullchain.pem /pad/naar/vault/tls/
     chown $USER:$USER /pad/naar/vault/tls/*.pem

     # Herstart Vault om de nieuwe certificaten te laden
     cd /pad/naar/vault
     docker-compose restart vault
   "
   ```

3. Maak het script uitvoerbaar:

   ```bash
   sudo chmod +x /usr/local/bin/renew_vault_certs.sh
   ```

4. Voeg een wekelijkse cronjob toe:

   ```bash
   sudo crontab -e
   ```

   Voeg deze regel toe om het script wekelijks uit te voeren:

   ```text
   0 3 * * 0 /usr/local/bin/renew_vault_certs.sh >/dev/null 2>&1
   ```

   (Dit voert het script elke zondag om 03:00 uit)

## 🔧 Vault initialiseren in productie

1. **Zorg dat je certificaten in de juiste map staan**

   Certificaten moeten in `vault/tls/` staan:
   - `privkey.pem`: Private key
   - `fullchain.pem`: Certificaat keten

2. **Start Vault in productie modus**

   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. **Initialiseer Vault**

   ```bash
   docker-compose -f docker-compose.prod.yml exec vault vault operator init
   ```

   - **BELANGRIJK**: Bewaar de gegenereerde unseal keys en root token veilig!
   - Bewaar deze gegevens op een veilige plaats, zoals een wachtwoordmanager

4. **Unseal Vault**

   ```bash
   docker-compose -f docker-compose.prod.yml exec vault vault operator unseal
   ```

   Voer dit commando uit met 3 verschillende unseal keys (standaard zijn er 5 keys waarvan je er 3 nodig hebt).

## 🔑 Basis gebruik van Vault

### Inloggen

#### Ontwikkelomgeving

```bash
docker-compose -f docker-compose.dev.yml exec vault vault login
```

Gebruik de token `root-token-dev` zoals geconfigureerd in .env.vault.dev.

#### Productieomgeving

```bash
docker-compose -f docker-compose.prod.yml exec vault vault login
```

Gebruik de root token die je hebt ontvangen bij het initialiseren.

### Gegevens toevoegen

```bash
# Maak een nieuw geheim aan voor een klant
vault kv put secret/klanten/klant123/api-keys \
  wordpress="wp_1234567890" \
  openai="sk-1234567890"

# Maak een nieuw geheim aan voor een andere klant
vault kv put secret/klanten/klant456/database \
  username="dbuser" \
  password="veilig-wachtwoord" \
  host="db.example.com"
```

### Gegevens opvragen

```bash
# Haal alle gegevens op voor een klant
vault kv get secret/klanten/klant123/api-keys

# Haal een specifieke waarde op
vault kv get -field=wordpress secret/klanten/klant123/api-keys
```

## 🌐 Web Interface

- Productie (met TLS): `https://vault.hummer.ai:49281`
- Ontwikkeling (zonder TLS): `http://localhost:49281`

## 🔒 Beveiliging

### Aanbevolen maatregelen

1. **Firewall**

   - Beperk toegang tot de Vault poort (standaard 49281) tot bekende IP-adressen

   - Beperk toegang tot poort 8200/8201 tot bekende IP-adressen
   - Gebruik een Web Application Firewall (WAF)

2. **Backup**

   - Maak regelmatig backups van de `vault/data` map
   - Bewaar backups versleuteld op een veilige locatie

3. **Toegangscontrole**

   - Gebruik AppRole of andere auth methods in plaats van root token
   - Implementeer het principe van minste privilege

4. **Monitoring**
   - Monitor Vault's gezondheid en prestaties
   - Stel alerts in voor verdachte activiteiten

## 🛠 Onderhoud

### Vault herstarten

```bash
# Ontwikkelomgeving
docker-compose -f docker-compose.dev.yml restart vault

# Productieomgeving
docker-compose -f docker-compose.prod.yml restart vault
```

### Logs bekijken

```bash
# Ontwikkelomgeving
docker-compose -f docker-compose.dev.yml logs -f vault

# Productieomgeving
docker-compose -f docker-compose.prod.yml logs -f vault
```

### Backup maken

```bash
# Ontwikkelomgeving
docker-compose -f docker-compose.dev.yml stop vault
cp -r vault/data vault/backup-dev-$(date +%Y%m%d)
docker-compose -f docker-compose.dev.yml start vault

# Productieomgeving
docker-compose -f docker-compose.prod.yml stop vault
cp -r vault/data vault/backup-prod-$(date +%Y%m%d)
docker-compose -f docker-compose.prod.yml start vault
```

## 👥 Klantbeheer

### Namespaces per klant aanmaken (Enterprise feature)

> **Let op**: Namespaces zijn een Enterprise feature van Vault. Als je de gratis versie gebruikt, kun je in plaats daarvan werken met verschillende paden en policies.

```bash
# Maak een namespace voor een klant
vault namespace create klant123

# Gebruik de namespace
vault namespace use klant123
# of
VAULT_NAMESPACE=klant123 vault <commando>
```

### Policies per klant aanmaken (Gratis versie)

1. **Maak een policy bestand** (bijv. `klant123-policy.hcl`)

```hcl
# Toegang tot alleen de eigen klantgegevens
path "secret/data/klanten/klant123/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Geen toegang tot gegevens van andere klanten
path "secret/data/klanten/*" {
  capabilities = []
}
```

2. **Upload de policy naar Vault**

```bash
vault policy write klant123 klant123-policy.hcl
```

3. **Maak een token voor de klant**

```bash
vault token create -policy=klant123 -display-name="Klant123 API Token"
```

### AppRole authenticatie per klant (Aanbevolen voor API toegang)

1. **Schakel de AppRole auth methode in**

```bash
vault auth enable approle
```

2. **Maak een AppRole voor de klant**

```bash
vault write auth/approle/role/klant123 \
    token_policies="klant123" \
    token_ttl=1h \
    token_max_ttl=4h
```

3. **Haal de RoleID op**

```bash
vault read auth/approle/role/klant123/role-id
# Bewaar de role_id voor de klant
```

4. **Genereer een SecretID**

```bash
vault write -f auth/approle/role/klant123/secret-id
# Geef de secret_id veilig door aan de klant
```

5. **Klant kan inloggen met**

```bash
vault write auth/approle/login \
    role_id="<role_id>" \
    secret_id="<secret_id>"
```

### Klantgegevens beheren

```bash
# Als admin: Gegevens toevoegen voor een klant
vault kv put secret/klanten/klant123/api-keys \
  wordpress="wp_1234567890" \
  openai="sk-1234567890"

# Als klant (met eigen token): Gegevens opvragen
VAULT_TOKEN=<klant-token> vault kv get secret/klanten/klant123/api-keys
```

## 📚 Documentatie

- [HashiCorp Vault Documentatie](https://www.vaultproject.io/docs)
- [Vault KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Vault Policies](https://www.vaultproject.io/docs/concepts/policies)
- [Vault AppRole Auth Method](https://www.vaultproject.io/docs/auth/approle)
- [Vault Best Practices](https://learn.hashicorp.com/tutorials/vault/production-hardening)

## 📝 Licentie

Dit project is gelicentieerd onder de [MIT Licentie](LICENSE).

## 📧 Contact

Voor vragen of ondersteuning, neem contact op met het beheerders team.
