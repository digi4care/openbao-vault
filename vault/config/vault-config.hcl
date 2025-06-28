# Basis configuratie
ui = true
disable_mlock = true

# Eenvoudige bestandsopslag voor een enkele instantie
storage "file" {
  path = "/vault/file"
}

# TCP Listener zonder TLS (TLS wordt afgehandeld door LiteSpeed)
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"  # TLS wordt afgehandeld door LiteSpeed als reverse proxy
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# API adres
api_addr = "http://127.0.0.1:8200"

# Beveiligingsinstellingen
default_lease_ttl = "768h"
max_lease_ttl = "8760h"  # 1 jaar

# Logging
log_level = "info"
log_format = "standard"

# Automatisch unseal uitschakelen voor eenvoudige setup
# disable_sealwrap = true
