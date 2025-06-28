FROM quay.io/openbao/openbao:2.3.1

# Installeer jq voor JSON verwerking in scripts
RUN apk add --no-cache jq

# Kopieer scripts naar de container
COPY scripts/ /opt/bin/

# Zorg ervoor dat de scripts uitvoerbaar zijn
RUN chmod +x /opt/bin/*.sh

ENTRYPOINT ["docker-entrypoint.sh"]
# De CMD wordt overschreven door docker-compose
