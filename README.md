# DevSecOps & Supply Chain Security

Sécurise la chaîne d'approvisionnement logicielle de la plateforme des
Projets 1-3 : du code source jusqu'au déploiement Kubernetes. Construit
en suivant
[Projet-4-DevSecOps-Guide.md](Projet-4-DevSecOps-Guide.md).

## ⚠️ Ce dépôt ne contient PAS tout le Projet 4 — et c'est voulu

Contrairement aux Projets 2/3, les étapes 1 à 4 du guide (SAST, Trivy,
SBOM, Cosign) sont des étapes de **pipeline CI**, pas des ressources
Kubernetes — elles vivent dans `.github/workflows/` du dépôt
[gitops-platform](https://github.com/amadouldiallo/gitops-platform),
puisque c'est le pipeline CI de CETTE app qu'on sécurise. Un pipeline de
sécurité appartient au code qu'il protège, pas à un dépôt tiers.

Ce dépôt-ci contient les étapes 5 à 8 : ce qui s'applique au **cluster**
lui-même (Kyverno, Falco, NetworkPolicy durcies, tests de sécurité) —
déployées sur `gitops-platform`, le cluster GKE déjà provisionné (Projet
2), sans nouvelle infrastructure GCP.

| Étape | Où | Dépôt |
|---|---|---|
| 1 — SAST | `.github/workflows/` | gitops-platform |
| 2 — Trivy | `.github/workflows/` | gitops-platform |
| 3 — SBOM | `.github/workflows/` | gitops-platform |
| 4 — Cosign | `.github/workflows/` | gitops-platform |
| 5 — Kyverno | `k8s/kyverno/` | **ce dépôt** |
| 6 — Falco | `k8s/falco/` | **ce dépôt** |
| 7 — NetworkPolicy | `k8s/network-security/` | **ce dépôt** |
| 8 — Tests de sécurité | `docs/security-tests.md` | **ce dépôt** |

❓ **Pourquoi aucun `terraform/` ici** (contrairement aux Projets 2/3) :
Kyverno, Falco et les NetworkPolicy sont des ressources Kubernetes pures,
sans la moindre dépendance à une nouvelle ressource GCP. La seule
ressource cloud nécessaire à ce projet — Workload Identity Federation
pour que la CI de gitops-platform pousse des images sans clé statique —
appartient logiquement au module `iam` **déjà existant** de
gitops-platform, pas à un module dupliqué ici.

## Comment lire ce dépôt

Mêmes symboles que les Projets 1-3 en tête de bloc de commentaire :

| Symbole | Signification |
|---|---|
| 🎯 | Le concept — ce que fait le composant, en langage simple |
| 🧠 | Analogie — pour ancrer le concept dans quelque chose de concret |
| ❓ | Pourquoi c'est important — la conséquence si on s'en passe |
| ⚠️ | Piège — une erreur facile à faire, rencontrée en écrivant ce code |
| 🔭 | Pour aller plus loin — une amélioration volontairement pas faite ici |

## Avancement

| Étape du guide | Statut |
|---|---|
| 1 — SAST | ✅ **testé sur le vrai pipeline** (dépôt gitops-platform) |
| 2 — Dependency Security (Trivy) | ✅ **3 vraies CVE trouvées et corrigées** (dépôt gitops-platform) |
| 3 — SBOM (Syft) | ✅ **SBOM réel généré (337 Ko), vérifié** (dépôt gitops-platform) |
| 4 — Image Signing (Cosign) | ✅ **signature vérifiée + contrôle négatif** (dépôt gitops-platform) |
| 5 — Admission Control (Kyverno) | ⬜ à faire |
| 6 — Runtime Security (Falco) | ⬜ à faire |
| 7 — Network Security | ⬜ à faire |
| 8 — Security Testing | ⬜ à faire |

## Étapes 1-4 — CI de sécurité (dépôt gitops-platform)

Voir [gitops-platform/.github/workflows/security-ci.yml](https://github.com/amadouldiallo/gitops-platform/blob/main/.github/workflows/security-ci.yml)
et sa section [🔒 Évolutions liées au Projet 4](https://github.com/amadouldiallo/gitops-platform#-évolutions-liées-au-projet-4)
pour le détail complet. Résumé de ce qui a été RÉELLEMENT trouvé et
vérifié, pas juste "la CI est verte" :

- **SAST (Bandit)** : 0 issue sur le code du backend, vérifié localement
  puis en CI.
- **Trivy** a trouvé **3 vraies CVE HIGH** (`starlette==0.41.3`, avec
  correctif disponible pour chacune) — bloquées par le pipeline comme
  prévu, corrigées, re-vérifiées à 0 CVE restante.
- **SBOM** (Syft, SPDX) : 337 Ko générés par build, publiés comme
  artefact du run.
- **Cosign** (keyless, OIDC GitHub Actions) : signature vérifiée après
  coup depuis un poste externe, avec l'identité EXACTE attendue
  (dépôt + workflow + branche) — et un contrôle négatif confirmant
  qu'une identité incorrecte est bien rejetée, pas juste que la bonne
  passe.

⚠️ **Piège d'outillage rencontré en testant en local** : cette machine
tourne macOS 12, plus supporté par Homebrew — installer `cosign`
localement déclenchait une compilation depuis les sources (Go) qui a
rempli le disque (`no space left on device`). Contourné en téléchargeant
directement les binaires statiques précompilés depuis les releases
GitHub de chaque outil (`trivy`, `cosign`) — aucune compilation, aucun
Homebrew, quelques dizaines de Mo chacun.

---

*Les sections Étapes 5-8 seront ajoutées au fil de l'avancement réel,
testées sur le cluster avant d'être documentées — même discipline que les
Projets 1 à 3.*
