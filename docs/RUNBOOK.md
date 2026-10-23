# Runbook d'exploitation de VéloCité

A FAIRE : la section Retour arrière le mercredi (atelier 6), la section
Reprise du bilan le jeudi (atelier 7), une section par alerte le jeudi
après-midi (atelier 8). Relu par un autre binôme le vendredi.

Chaque section suit le même ordre :

1. **Ce qu'on voit** : le symptôme, ou l'alerte.
2. **Vérifier** : les commandes qui confirment ou infirment, avec le
   résultat attendu.
3. **Agir** : le geste, et seulement après avoir vérifié.
4. **Confirmer** : la preuve que c'est réglé.

Les alertes renvoient ici par leur annotation `runbook` : chaque section
porte une ancre explicite, sans accent, que GitHub ne modifie pas.

---

<a id="restauration"></a>
## Restauration des données

### Ce qu'on voit

Le StatefulSet PostgreSQL ou sa PVC `donnees-postgres-0` a été perdu, ou la
vérification de la donnée du jour ne retrouve plus les 250 trajets du client
`flotte@cote-livraisons.example`. Le RPO est l'âge de la dernière sauvegarde
réussie : toute donnée ajoutée après celle-ci peut être perdue.

### Vérifier

```powershell
./scripts/donnees-du-jour.ps1 -Verifier
Get-ChildItem sauvegardes/velocite-dev-*.sql | Sort-Object Name
kubectl -n velocite-dev get statefulset,pod,pvc
```

Choisir la sauvegarde la plus récente créée avant l'incident. La preuve à
retrouver est `250` trajets et l'empreinte `9b7904d63be2`.

### Agir

Après une perte de disque, recréer d'abord la base vide depuis le manifeste,
puis attendre son démarrage et rejouer une sauvegarde locale. Les fichiers SQL
restent hors de Git car ils contiennent des données personnelles.

```powershell
kubectl apply -k deploy/overlays/dev
./scripts/restaurer.ps1 -Env dev
```

Le RTO est la durée affichée par `restaurer.ps1`, mesurée depuis l'attente de
PostgreSQL jusqu'à la fin de la restauration. La relever à chaque exercice ou
incident avec l'heure de la sauvegarde utilisée.

### Mesures de l'exercice du 23 octobre 2026

La sauvegarde utilisée a été terminée à 12:13:17 (heure de Paris) et le nouveau
disque a été créé à 12:13:38 : le RPO constaté est donc de 21 secondes. La
restauration a terminé en 2 secondes : RTO mesuré de 2 secondes, hors temps de
diagnostic et de recréation du StatefulSet.

### Confirmer

```powershell
./scripts/donnees-du-jour.ps1 -Verifier
kubectl -n velocite-dev rollout status statefulset/postgres
```

La commande doit annoncer les 250 trajets et l'empreinte `9b7904d63be2` ; le
StatefulSet doit avoir un replica prêt. La création du client doit être
antérieure au nouveau disque : elle provient alors bien de la sauvegarde.

---

<a id="service-indisponible"></a>
## Service indisponible

### Ce qu'on voit

L'alerte indique qu'un déploiement n'a plus aucun pod prêt. Les clients peuvent
voir des erreurs 5xx ou des délais d'attente sur les routes exposées.

### Vérifier

```powershell
kubectl -n velocite-dev get pods
kubectl -n velocite-dev describe deployment/api
kubectl -n velocite-dev get events --sort-by=.lastTimestamp
```

### Agir

Corriger la cause identifiée (configuration, image ou dépendance), puis
réappliquer le manifeste versionné. Ne pas modifier le déploiement à la main.

### Confirmer

```powershell
kubectl -n velocite-dev rollout status deployment/api
./scripts/smoke.ps1 -Env dev
```

---

<a id="disponibilite-client-degradee"></a>
## Disponibilité client dégradée

### Ce qu'on voit

Le client témoin observe plus de 1 % d'échecs sur une route pendant au moins
deux minutes. Cette alerte mesure le service tel qu'il est reçu par le client,
pas uniquement l'état interne des pods.

### Vérifier

```powershell
kubectl -n observabilite port-forward svc/prometheus-server 9090:80
# Dans Prometheus : sum by (route) (rate(velocite_client_requests_total{namespace="velocite-dev",code=~"5..|erreur"}[5m])) / sum by (route) (rate(velocite_client_requests_total{namespace="velocite-dev"}[5m]))
kubectl -n velocite-dev get pods
```

### Agir

Identifier la route et les codes en erreur, puis vérifier nginx, l'API et leurs
dépendances. Restaurer le déploiement ou la dépendance fautive avant de relancer
les clients.

### Confirmer

Après cinq minutes sans nouvel échec, l'alerte repasse à `inactive` et le
tableau Grafana affiche une disponibilité supérieure ou égale à 99 %.

### Exercice du 22 octobre 2026

Sur `velocite-dev`, l'API a été arrêtée à 15:06:34 puis remise à un replica à
15:09:33 (heure de Paris). L'alerte est passée à `pending` à 15:07:27, à
`firing` à 15:09:57, puis à `inactive` à 15:15:27. Ce délai après le retour
est normal : la fenêtre de cinq minutes contient encore les erreurs précédentes.

---

<a id="salve-exports-data-science"></a>
## Salve d'exports data science

### Ce qu'on voit

Plus de 1 000 lignes ont été exportées par le compte `datascientist` en cinq
minutes. Ce peut être une analyse prévue, mais le volume doit être justifié.

### Vérifier

```powershell
kubectl -n observabilite port-forward svc/prometheus-server 9090:80
# Dans Prometheus : increase(velocite_rows_exported_total{namespace="velocite-dev",role="datascientist"}[5m])
```

Comparer la salve à la demande d'analyse et aux logs d'accès de l'API.

### Agir

Si l'export n'est pas attendu, suspendre le compte ou son jeton selon la
procédure d'accès, puis préserver les journaux nécessaires à l'enquête.

### Confirmer

Le volume cesse d'augmenter ; l'alerte redevient `inactive` après la fenêtre de
cinq minutes et la période `for`.

---

<a id="retour-arriere"></a>
## Retour arrière (une mise à jour qui casse)

### Ce qu'on voit

Après le déploiement d'une nouvelle image, `kubectl rollout status` indique
`exceeded its progress deadline`. Un pod de la nouvelle révision est en
`CrashLoopBackOff`, mais le service peut encore répondre : avec
`maxUnavailable: 0`, l'ancienne révision reste disponible tant que la nouvelle
n'est pas prête.

### Vérifier

Depuis la racine du dépôt, identifier d'abord la révision en échec et le pod
concerné :

```powershell
kubectl -n velocite-dev rollout status deployment/api
kubectl -n velocite-dev get pods
kubectl -n velocite-dev describe pod NOM_DU_POD
kubectl -n velocite-dev logs NOM_DU_POD --previous
kubectl -n velocite-dev rollout history deployment/api
./scripts/smoke.ps1 -Env dev -PendantIncident
```

`NOM_DU_POD` est le nom du pod `api` en échec, lu dans `get pods`. Le code de
sortie et les logs doivent expliquer la panne ; pendant l'incident, le smoke
test doit continuer à confirmer que les clients reçoivent une réponse.

### Agir

Rétablir immédiatement l'ancienne révision dans le cluster :

```powershell
kubectl -n velocite-dev rollout undo deployment/api
kubectl -n velocite-dev rollout status deployment/api
```

Ensuite, corriger la configuration ou le manifeste dans le dépôt, puis
redéployer avec `kubectl apply -k deploy/overlays/dev`. Ne pas utiliser
`kubectl edit` ou `kubectl set env` : ces modifications seraient perdues au
prochain `apply`.

### Confirmer

```powershell
./scripts/smoke.ps1 -Env dev
kubectl diff -k deploy/overlays/dev
```

Le smoke test doit être entièrement vert et `kubectl diff` ne doit rien
afficher. La version corrigée peut alors être promue en changeant le tag de
l'overlay prod, puis en appliquant et testant prod de la même manière.

---

<a id="reprise-du-bilan"></a>
## Reprise du bilan quotidien

### Ce qu'on voit

L'alerte `BilanEchoue` est déclenchée, ou `BilanEnRetard` indique qu'aucun
bilan réussi n'a été publié depuis plus de 26 heures. Le statut du dernier
workflow peut être `Failed` ou `Error` ; l'étape `signaler` publie ce statut
dans la Pushgateway même si le pipeline s'est arrêté avant `publish`.

### Vérifier

Lister d'abord les exécutions, puis examiner celle en échec. Les logs des pods
réussis sont supprimés par Argo, il faut donc suivre les logs pendant un essai
ou utiliser Loki quand il est disponible.

```powershell
argo -n velocite-dev list
argo -n velocite-dev get NOM_DU_WORKFLOW
argo -n velocite-dev logs NOM_DU_WORKFLOW
kubectl -n velocite-dev get cronworkflow bilan-quotidien -o yaml
kubectl -n velocite-dev get pods
```

Un code 75 signifie une panne temporaire : l'étape doit être réessayée jusqu'à
trois fois avec un délai croissant. Un code 2 signale une donnée invalide et un
code 78 une configuration absente : les relancer ne peut pas corriger la cause.

### Agir

Corriger la cause avant toute relance (par exemple la connectivité vers
PostgreSQL ou Garage pour un code 75, ou la donnée source pour un code 2), puis
lancer le bilan pour le jour concerné. Ne pas contourner le mutex : une seconde
exécution attend naturellement la fin de celle qui est en cours.

```powershell
kubectl -n velocite-dev apply -f workflows
argo -n velocite-dev submit --from workflowtemplate/bilan-quotidien -p date=2026-03-12
argo -n velocite-dev logs '@latest' --follow
```

### Confirmer

Le workflow doit finir en `Succeeded`, l'étape `signaler` doit avoir été
exécutée, et le nombre de lignes du jour ne doit pas augmenter si le bilan est
rejoué : les étapes sont idempotentes.

```powershell
argo -n velocite-dev get '@latest'
./scripts/compter-bilan.ps1 -Date 2026-03-12 -Env dev
kubectl -n velocite-dev get cronworkflow bilan-quotidien
```

---

<a id="budget-erreur"></a>
## Budget d'erreur consommé vite

### Ce qu'on voit

L'alerte `BudgetErreurConsommeVite` est déclenchée pour une route : plus de
14,4 % des appels du client témoin échouent à la fois sur les cinq dernières
minutes et sur l'heure écoulée. Elle signale une dégradation suffisamment forte
et durable pour épuiser rapidement le budget d'erreur du SLO à 99 %.

### Vérifier

```powershell
kubectl -n observabilite port-forward svc/prometheus-server 9090:80
# Dans Prometheus, vérifier les deux séries par namespace et route :
# velocite:echecs_client:ratio_rate5m
# velocite:echecs_client:ratio_rate1h
kubectl -n velocite-dev get pods
kubectl -n velocite-dev get events --sort-by=.lastTimestamp
kubectl -n velocite-dev logs deployment/nginx --tail=100
kubectl -n velocite-dev logs deployment/api --tail=100
```

Les deux ratios doivent dépasser `0.144` pour la même route. Vérifier les pods,
le frontal et l'API avant toute action afin de distinguer une indisponibilité de
l'API, une erreur du frontal ou une dépendance défaillante.

### Agir

Rétablir le composant en cause avec le manifeste versionné. Si l'API n'a plus de
pod prêt, remettre son nombre de replicas attendu, puis réappliquer l'overlay :

```powershell
kubectl -n velocite-dev scale deployment/api --replicas=1
kubectl apply -k deploy/overlays/dev
kubectl -n velocite-dev rollout status deployment/api
```

Ne pas modifier une configuration durable directement dans le cluster : toute
correction doit être reportée dans le dépôt avant le prochain déploiement.

### Confirmer

```powershell
kubectl -n velocite-dev get pods
./scripts/smoke.ps1 -Env dev
kubectl diff -k deploy/overlays/dev
```

Le déploiement doit être prêt, le smoke test doit réussir et `kubectl diff` ne
doit rien afficher. Après le retour à la normale, l'alerte disparaît lorsque la
fenêtre de cinq minutes ne contient plus assez d'échecs ; le ratio sur une heure
retombe ensuite progressivement.

### Exercice du 23 octobre 2026

Sur `velocite-dev`, l'API a été coupée à 10:48:02 puis remise à un replica vers
10:58 (heure de Paris). `BudgetErreurConsommeVite` a été observée en état
`firing` à 10:57:31 sur `/api/login`, puis était inactive à 11:05:14. Le délai
de retour est attendu : après le redémarrage, la fenêtre de cinq minutes doit
d'abord évacuer les erreurs de la coupure.
