# La zone complète, gérée comme du code. Reflète dns/zone.bind.
#
# PRÉREQUIS ET RISQUE
# Ce fichier ne s'applique qu'après avoir délégué la zone à Cloudflare, donc
# après avoir changé les serveurs de noms chez LWS. Or le domaine reçoit du
# courrier : la délégation transfère aussi la responsabilité des MX, SPF, DKIM
# et DMARC. Un enregistrement oublié ou mal recopié fait cesser la réception
# des e-mails, en silence et sans erreur.
#
# C'est pourquoi les enregistrements de courrier sont déclarés ici, et pas
# seulement ceux du web. Déléguer une zone partiellement n'existe pas.
#
#   tofu init && tofu plan

locals {
  # Un seul endroit à changer le jour où le serveur déménage.
  ip_web = var.ip_serveur

  # --- Web : le serveur OVH -------------------------------------------------
  hotes_web = {
    "@"           = "interface de production"
    "api"         = "API de production, flux SSE"
    "staging"     = "interface de préproduction"
    "api.staging" = "API de préproduction"
    "airbyte"     = "console Airbyte, derrière authentification"
  }

  # --- Courrier : infrastructure LWS, valeurs à ne pas inventer -------------
  alias_courrier = ["imap", "pop", "smtp"]
}

# --- Web ----------------------------------------------------------------------

resource "cloudflare_dns_record" "web" {
  for_each = local.hotes_web

  zone_id = var.zone_id
  name    = each.key
  type    = "A"
  content = local.ip_web
  ttl     = 300
  comment = each.value

  # Le proxy Cloudflare peut tamponner les réponses : le flux Server-Sent Events
  # de la conversation arriverait d'un bloc à la fin, ce qui supprime le
  # streaming et le suivi des agents. Il empêche aussi Caddy de gérer ses
  # propres certificats. On reste en DNS seul.
  proxied = false
}

resource "cloudflare_dns_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  type    = "CNAME"
  content = var.domaine
  ttl     = 86400
  proxied = false
}

# Aucun enregistrement AAAA : le VPS a une adresse IPv6, mais tant qu'elle n'est
# pas configurée sur la machine et dans Caddy, la déclarer enverrait les
# visiteurs en IPv6 vers un service qui ne répond pas — pendant que l'IPv4
# fonctionne, ce qui rend la panne invisible depuis un poste de développement.

# --- Courrier -----------------------------------------------------------------

resource "cloudflare_dns_record" "mx" {
  zone_id  = var.zone_id
  name     = "@"
  type     = "MX"
  content  = "mail.${var.domaine}"
  priority = 10
  ttl      = 86400
}

resource "cloudflare_dns_record" "mail" {
  zone_id = var.zone_id
  name    = "mail"
  type    = "A"
  content = var.ip_courrier
  ttl     = 21600
  comment = "serveur de courrier LWS"
}

resource "cloudflare_dns_record" "alias_courrier" {
  for_each = toset(local.alias_courrier)

  zone_id = var.zone_id
  name    = each.key
  type    = "CNAME"
  content = "mail.${var.domaine}"
  ttl     = 86400
}

resource "cloudflare_dns_record" "spf" {
  zone_id = var.zone_id
  name    = "@"
  type    = "TXT"
  content = var.spf
  ttl     = 86400
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine;"
  ttl     = 86400
}

resource "cloudflare_dns_record" "dkim" {
  zone_id = var.zone_id
  name    = "dkim._domainkey"
  type    = "TXT"
  content = var.dkim
  ttl     = 86400
}
