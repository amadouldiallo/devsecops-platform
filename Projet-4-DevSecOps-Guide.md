# Projet 4 — DevSecOps & Supply Chain Security
## Guide d'apprentissage pédagogique

**Objectif du projet :** sécuriser toute la chaîne d'approvisionnement logicielle, de la source jusqu'au déploiement Kubernetes — pas seulement le code, mais tout ce qui le compose et tout ce qui le fait tourner.

---

## Étape 1 — SAST

**🎯 Le concept**
Analyser le code source lui-même, sans l'exécuter, pour détecter des vulnérabilités et de mauvaises pratiques dès l'écriture.

**🧠 Analogie**
SAST est un correcteur qui relit une recette de cuisine à la recherche d'erreurs — sans jamais la cuisiner. Le code est lu statiquement, avant même d'être compilé ou lancé.

**❓ Pourquoi**
Trouver un bug de sécurité dans le code source coûte infiniment moins cher (temps, argent, réputation) que le trouver en production après une brèche.

**🛠️ Prompt Claude Code**
```
Intègre une analyse SAST dans le pipeline GitHub Actions : analyse le
code du backend à chaque Pull Request, avec un seuil qui bloque le merge
en cas de vulnérabilité critique.
```

---

## Étape 2 — Dependency Security (Trivy)

**🎯 Le concept**
Scanner les dépendances tierces et l'image Docker finale à la recherche de vulnérabilités connues (CVE).

**🧠 Analogie**
C'est le contrôle sanitaire à l'entrée d'un restaurant, qui vérifie la provenance de chaque ingrédient acheté à l'extérieur. Même si le chef (le code applicatif) est irréprochable, un ingrédient avarié (une librairie vulnérable) rend le plat dangereux.

**❓ Pourquoi**
La majorité des vulnérabilités en production ne viennent pas du code qu'on écrit, mais des dizaines de dépendances qu'on importe sans les auditer une par une.

**🛠️ Prompt Claude Code**
```
Ajoute Trivy au pipeline CI : `trivy fs .` pour scanner les dépendances
du projet, puis `trivy image` sur l'image Docker construite — le
pipeline doit échouer si une vulnérabilité CRITICAL ou HIGH sans
correctif est détectée.
```

---

## Étape 3 — SBOM (Syft + SPDX)

**🎯 Le concept**
Générer un inventaire exhaustif et structuré de tout ce qui compose une image : chaque paquet, chaque version, chaque licence.

**🧠 Analogie**
Le SBOM (Software Bill of Materials) est la liste d'ingrédients au dos d'un paquet alimentaire — sans elle, impossible de savoir rapidement si un produit contient un ingrédient rappelé, sans tout redémonter.

**❓ Pourquoi**
Quand une CVE critique est annoncée (type Log4Shell), la vraie question devient "est-ce qu'on est concernés, et où ?" — sans SBOM, des jours de recherche manuelle ; avec, une simple requête.

**🛠️ Prompt Claude Code**
```
Ajoute Syft au pipeline CI pour générer un SBOM au format SPDX pour
chaque image construite, et publie-le comme artefact du build
(sbom.spdx.json) attaché à la release.
```

---

## Étape 4 — Image Signing (Cosign)

**🎯 Le concept**
Signer cryptographiquement chaque image après le build, pour garantir qu'elle vient bien du pipeline CI officiel et n'a pas été modifiée depuis.

**🧠 Analogie**
C'est le sceau de cire sur une lettre officielle — n'importe qui peut la lire, mais le sceau prouve qu'elle vient bien de l'expéditeur annoncé. Sans signature, un registre compromis pourrait laisser pousser une image malveillante portant le même nom.

**❓ Pourquoi**
Sans signature vérifiable, "cette image vient de notre pipeline CI" est une affirmation, pas une garantie.

**🛠️ Prompt Claude Code**
```
Ajoute Cosign au pipeline CI pour signer chaque image après le build
(keyless signing via OIDC/GitHub Actions), et publie la signature avec
l'image sur le registre.
```

---

## Étape 5 — Admission Control (Kyverno)

**🎯 Le concept**
Un contrôleur qui inspecte chaque ressource Kubernetes à sa création et rejette celles qui violent une politique — avant même qu'un pod ne démarre.

**🧠 Analogie**
C'est le videur à l'entrée d'un club, qui vérifie la liste AVANT de laisser entrer — pas un agent qui patrouille après coup à l'intérieur. Une fois qu'un pod malveillant tourne déjà, c'est trop tard pour Kyverno ; son rôle est de l'empêcher d'entrer.

**❓ Pourquoi**
Sans admission control, les bonnes pratiques (non-root, image signée, registre approuvé) ne sont que des recommandations qu'un manifeste YAML direct peut contourner. Kyverno les transforme en règles obligatoires, pour tout le cluster.

**🛠️ Prompt Claude Code**
```
Installe Kyverno et crée 4 ClusterPolicy : interdire les conteneurs
privileged, exiger runAsNonRoot, n'autoriser que les images du
registre approuvé, et exiger que chaque image soit signée
(vérification Cosign).
```

---

## Étape 6 — Runtime Security (Falco)

**🎯 Le concept**
Surveiller en temps réel le comportement des conteneurs EN COURS D'EXÉCUTION, pour détecter ce que ni le scan d'image ni l'admission control n'auraient pu prévoir.

**🧠 Analogie**
Si Kyverno est le videur à l'entrée, Falco est la caméra de surveillance à l'intérieur — elle ne décide pas qui entre, mais repère un comportement anormal une fois à l'intérieur, même chez quelqu'un qui avait légitimement le droit d'entrer.

**❓ Pourquoi**
Une image parfaitement scannée et signée peut quand même être compromise après son déploiement (vulnérabilité 0-day, credential volé). Le runtime security est la dernière ligne de défense.

**🛠️ Prompt Claude Code**
```
Installe Falco sur le cluster avec les règles par défaut, puis ajoute
une règle personnalisée qui détecte l'ouverture d'un shell interactif
dans un conteneur en production (kubectl exec) — un comportement
rarement légitime hors debug.
```

---

## Étape 7 — Network Security (NetworkPolicy)

**🎯 Le concept**
Étendre le zero-trust déjà appliqué au Projet 2 pour verrouiller précisément qui peut communiquer avec qui, au niveau réseau.

**🧠 Analogie**
Reprend le plan de circulation du Projet 2 (frontend → backend → database), mais comme dernière barrière défense-en-profondeur : même si un attaquant compromet un pod, la NetworkPolicy l'empêche de se déplacer latéralement — comme des portes coupe-feu qui limitent la propagation d'un incendie même après qu'il ait démarré.

**❓ Pourquoi**
Sans segmentation stricte, un seul pod compromis devient un tremplin vers tout le reste du cluster. La NetworkPolicy transforme un incident localisé en incident qui RESTE localisé.

**🛠️ Prompt Claude Code**
```
Vérifie et durcis les NetworkPolicy existantes (Projet 2) : ajoute une
politique deny-all par défaut sur chaque namespace applicatif, puis
autorise explicitement uniquement les flux nécessaires
(frontend→backend, backend→database, monitoring→cibles à scraper).
```

---

## Étape 8 — Security Testing (chaos volontaire)

**🎯 Le concept**
Créer délibérément des ressources non conformes (pod privileged, image non signée, registre non approuvé) pour vérifier que chaque barrière construite la bloque RÉELLEMENT.

**🧠 Analogie**
C'est un pentest interne assumé — comme un serrurier qui essaie lui-même de crocheter la serrure qu'il vient d'installer, avant de la considérer comme sécurisée. Une politique jamais testée contre un cas réel est une hypothèse, pas une garantie.

**❓ Pourquoi**
Une ClusterPolicy Kyverno mal écrite (regex trop permissive, mauvais scope) peut sembler correcte en la relisant, tout en laissant passer exactement ce qu'elle était censée bloquer — seul un test réel le révèle.

**🛠️ Prompt Claude Code**
```
Crée volontairement des manifestes non conformes (pod privileged, pod
avec hostPath, conteneur root, image non signée, image d'un registre
non approuvé), tente de les déployer, et documente dans
docs/security-tests.md lesquels ont été bloqués par Kyverno, avec le
message d'erreur exact retourné.
```

---

## 💡 Lien avec les projets précédents

Ce projet ne part pas de zéro : il ajoute une couche de vérification obligatoire, côté cluster, à des pratiques déjà présentes en amont — le scan Terraform du Projet 1 (CI) reste un contrôle côté CI, que n'importe qui peut contourner en appliquant un manifeste directement. Kyverno et Falco déplacent une partie de cette vérification côté cluster lui-même — c'est la différence entre "on a vérifié avant" et "on empêche/détecte, quoi qu'il arrive".
