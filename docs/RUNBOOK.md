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

<a id="service-indisponible"></a>
## Service indisponible

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
