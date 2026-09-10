variable "project_id" {
  description = "ID du projet GCP hébergeant déjà le cluster gitops-platform"
  type        = string
}

variable "region" {
  description = "Région GCP par défaut"
  type        = string
  default     = "europe-west1"
}
