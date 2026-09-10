# =============================================================================
# Accès registre pour Kyverno — le seul besoin Terraform réel de ce projet
# =============================================================================
# ❓ Pourquoi juste CE module, rien d'autre
# Kyverno, Falco et les NetworkPolicy (Étapes 5-7) sont des ressources
# Kubernetes pures — aucune n'a besoin de nouvelle infrastructure GCP,
# SAUF Kyverno pour vérifier une signature Cosign sur un registre privé
# (voir modules/registry-access pour le piège rencontré en le découvrant).
module "registry_access" {
  source     = "../../modules/registry-access"
  project_id = var.project_id
  region     = var.region
}
