# Tests de sécurité — chaos volontaire

**Méthode** : 5 manifestes délibérément non conformes, chacun isolant
**une seule** violation à la fois (les 4 autres critères restent
conformes), déployés pour de vrai dans `task-tracker` contre les
politiques Kyverno réellement actives (`validationFailureAction:
Enforce`). Manifestes dans [k8s/security-tests/](../k8s/security-tests/).

## Résultats

| # | Test | Résultat | Politique |
|---|---|---|---|
| 1 | Conteneur `privileged: true` | ✅ **Bloqué** (par 2 politiques indépendantes) | `disallow-privileged-containers` + `require-run-as-non-root` |
| 2 | Volume `hostPath` (`/` du node) | ⚠️ **Admis au premier essai** — corrigé en direct, voir plus bas | *(aucune au départ)* → `disallow-host-path` |
| 3 | Conteneur sans `runAsNonRoot` | ✅ **Bloqué** | `require-run-as-non-root` |
| 4 | Image jamais signée (même dépôt, tag non passé par la CI) | ✅ **Bloqué** | `verify-backend-image-signature` |
| 5 | Image d'un registre public (Docker Hub) | ✅ **Bloqué** | `restrict-image-registries` |

## Détail — messages d'erreur EXACTS retournés par le serveur

### 1. Pod privileged

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/task-tracker/sectest-privileged was blocked due to the following policies
disallow-privileged-containers:
  privileged-containers: 'validation error: Les conteneurs privileged sont interdits dans task-tracker. rule privileged-containers failed at path /spec/containers/0/securityContext/privileged/'
require-run-as-non-root:
  run-as-non-root: 'validation error: runAsNonRoot doit être explicitement true (pod ou conteneur). rule run-as-non-root[0] failed at path /spec/securityContext/runAsNonRoot/ rule run-as-non-root[1] failed at path /spec/containers/0/securityContext/runAsNonRoot/'
```

Intéressant : **deux** politiques indépendantes ont rejeté ce pod (je
n'avais pas non plus réglé `runAsNonRoot` sur ce manifeste précis) — une
preuve concrète de défense en profondeur : même si UNE politique avait
un trou, l'autre aurait quand même bloqué ce pod précis.

### 3. Conteneur root

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/task-tracker/sectest-root was blocked due to the following policies
require-run-as-non-root:
  run-as-non-root: 'validation error: runAsNonRoot doit être explicitement true (pod ou conteneur). rule run-as-non-root[0] failed at path /spec/securityContext/runAsNonRoot/ rule run-as-non-root[1] failed at path /spec/containers/0/securityContext/'
```

### 4. Image non signée

```
Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
resource Pod/task-tracker/sectest-unsigned was blocked due to the following policies
verify-backend-image-signature:
  verify-cosign-keyless: 'failed to verify image europe-west1-docker.pkg.dev/devops-498817/gitops-images/task-tracker-backend:unsigned-test: .attestors[0].entries[0].keyless: no signatures found'
```

Le tag `unsigned-test` pointait vers un digest RÉEL (vérifié au
préalable avec `cosign verify` en dehors du cluster : `Error: no
signatures found`) — jamais passé par le pipeline CI sécurisé (Étapes
1-4), poussé directement au registre pour ce test. Supprimé du registre
une fois le test terminé (`gcloud artifacts docker images delete`).

### 5. Registre non approuvé

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/task-tracker/sectest-unapproved-registry was blocked due to the following policies
restrict-image-registries:
  approved-registry-only: 'validation error: Seules les images du registre approuvé (europe-west1-docker.pkg.dev/devops-498817/gitops-images) sont autorisées. rule approved-registry-only failed at path /spec/containers/0/image/'
```

## Le résultat le plus important : le test qui a RÉUSSI à passer

Test 2 (`hostPath` monté sur `/` du node) a été **admis sans erreur** :
```
pod/sectest-hostpath created
```

Vérifié que ce n'était pas juste "techniquement autorisé mais sans
conséquence" — un accès réel a été confirmé :
```
$ kubectl exec sectest-hostpath -n task-tracker -- cat /host/etc/passwd
ntp:!:203:203:network time protocol daemon:/dev/null:/bin/false
sshd:!:204:204:ssh daemon:/dev/null:/bin/false
root:x:0:0:root:/root:/bin/bash
...
```

**Root cause** : aucune des 4 `ClusterPolicy` de l'Étape 5 ne couvre les
volumes `hostPath` — le guide en demandait 4 précises (privileged,
non-root, registre, signature), aucune ne portait sur ce vecteur, alors
même que l'Étape 8 du guide le liste explicitement comme scénario à
tester. Un exemple concret et vécu de ce que l'Étape 8 décrit : *"une
politique qui ne bloque pas ce qu'elle est censée bloquer est un faux
sentiment de sécurité pire que l'absence de politique"* — sauf qu'ici,
ce n'est même pas que la politique était mal écrite, c'est qu'elle
n'existait pas du tout pour ce cas.

**Corrigé en direct** : ajout d'une 5ᵉ `ClusterPolicy`
(`disallow-host-path`, voir `k8s/kyverno/policies.yaml`) — puis
**re-testé** avec le même manifeste :

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/task-tracker/sectest-hostpath was blocked due to the following policies
disallow-host-path:
  host-path: 'validation error: Les volumes hostPath sont interdits dans task-tracker. rule host-path failed at path /spec/volumes/0/hostPath/'
```

## Conclusion

4 des 5 vecteurs testés étaient déjà correctement bloqués par les
politiques de l'Étape 5. Le 5ᵉ (`hostPath`) a révélé un vrai trou de
couverture — trouvé en testant, pas en relisant du YAML — corrigé et
re-vérifié avant de documenter ce fichier. C'est précisément la valeur
de cette étape : elle a changé le nombre RÉEL de politiques actives sur
ce cluster (4 → 5), pas seulement produit un rapport.

Tous les pods de test ont été supprimés après vérification — aucun ne
persiste sur le cluster.
