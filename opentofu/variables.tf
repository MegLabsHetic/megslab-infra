variable "domaine" {
  description = "Le domaine gere par cette zone."
  type        = string
  default     = "exemple.fr"
}

variable "zone_id" {
  description = "Identifiant de la zone Cloudflare, visible sur la page d'accueil du domaine."
  type        = string
}

variable "ip_serveur" {
  description = "Adresse IPv4 du serveur qui sert l'application web."
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.ip_serveur))
    error_message = "ip_serveur doit etre une adresse IPv4."
  }
}

variable "ip_courrier" {
  description = "Adresse du serveur de courrier LWS. Ne pas modifier sans verifier dans le panel."
  type        = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.ip_courrier))
    error_message = "ip_courrier doit etre une adresse IPv4."
  }
}

# SPF et DKIM sont des variables plutot que des valeurs en dur : ce sont les
# enregistrements qu'un copier-coller approximatif casse le plus facilement, et
# les isoler force a les relire depuis le panel LWS avant tout changement.

variable "spf" {
  description = "Enregistrement SPF, recopie a l'identique depuis LWS."
  type        = string
}

variable "dkim" {
  description = "Enregistrement DKIM, recopie a l'identique depuis LWS."
  type        = string
}
