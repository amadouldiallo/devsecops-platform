# =============================================================================
# Lecture du registre pour Kyverno — Workload Identity, découverte en marche
# =============================================================================
#
# 🎯 Le concept
# Kyverno (namespace `kyverno`, cluster gitops-platform) doit appeler
# directement l'API du registre pour vérifier une signature Cosign (image,
# signature, entrée Rekor) — un appel GCP FAIT PAR LE POD lui-même, pas
# par kubelet (qui, lui, tire déjà les images via l'identité du NODE, un
# mécanisme séparé). Sans identité GCP propre, ce pod n'a AUCUN accès au
# registre, même privé.
#
# ⚠️ Piège rencontré pour de vrai, en observant l'admission réelle d'un
# pod : "DENIED: Permission 'artifactregistry.repositories.downloadArtifacts'
# denied ... (or it may not exist)". Piège facile à mal diagnostiquer —
# le message donne l'impression que le REGISTRE ou le RÔLE est mal
# configuré, alors que le vrai problème est qu'AUCUNE identité GCP n'est
# liée à ce pod du tout (contrairement aux nodes GKE, dont le SA a déjà
# `artifactregistry.reader` sur tout le projet depuis le Projet 2 — un
# pod ordinaire n'hérite PAS de cette identité pour ses propres appels
# API, seul kubelet l'utilise, en interne, pour les pulls d'image).
#
# ❓ Pourquoi ce module existe alors que le README annonçait "pas de
# Terraform ici" : cette découverte a été faite EN TESTANT, après avoir
# écrit cette annonce — corrigée ici plutôt que contournée. Même
# discipline que le reste de ce portfolio : la documentation suit ce qui
# a été vérifié, pas l'inverse.

resource "google_service_account" "kyverno" {
  project      = var.project_id
  account_id   = "kyverno-registry-reader"
  display_name = "Kyverno — lecture du registre pour vérification Cosign"
}

# Accès scopé AU DÉPÔT précis (pas au projet entier) — Kyverno n'a besoin
# que de LIRE les images de gitops-images pour vérifier leur signature,
# jamais d'en pousser ni de toucher à un autre dépôt.
resource "google_artifact_registry_repository_iam_member" "kyverno_reader" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_registry_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.kyverno.email}"
}

resource "google_service_account_iam_member" "kyverno_workload_identity" {
  service_account_id = google_service_account.kyverno.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}
