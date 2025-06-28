FROM quay.io/openbao/openbao:2.3.1

# Installeer jq voor JSON verwerking in scripts
RUN apk add --no-cache jq

# Maak de directory voor gemounte scripts
RUN mkdir -p /opt/bin

ENTRYPOINT ["docker-entrypoint.sh"]
# De CMD wordt overschreven door docker-compose
