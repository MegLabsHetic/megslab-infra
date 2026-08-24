terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  # Lu depuis la variable d'environnement CLOUDFLARE_API_TOKEN.
  # Le jeton n'apparait jamais dans un fichier : ni ici, ni dans les tfvars.
  # Portee minimale suffisante : Zone.DNS -> Edit, sur cette zone uniquement.
}
