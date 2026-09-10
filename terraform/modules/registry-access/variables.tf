variable "project_id" {
  description = "ID du projet GCP hébergeant déjà le cluster gitops-platform et le registre gitops-images"
  type        = string
}

variable "region" {
  description = "Région du dépôt Artifact Registry"
  type        = string
  default     = "europe-west1"
}

variable "artifact_registry_repository" {
  description = "Nom du dépôt Artifact Registry à lire (le même que celui utilisé par la CI, Étape 1-4)"
  type        = string
  default     = "gitops-images"
}

variable "k8s_namespace" {
  description = "Namespace Kubernetes du ServiceAccount à lier"
  type        = string
  default     = "kyverno"
}

variable "k8s_service_account" {
  description = "Nom du ServiceAccount Kubernetes (vérifié via kubectl get sa -n kyverno, pas supposé)"
  type        = string
  default     = "kyverno-admission-controller"
}
