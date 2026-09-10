terraform {
  required_version = ">= 1.9"

  # Bloc volontairement VIDE — voir Projet 1 pour l'explication complète.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
