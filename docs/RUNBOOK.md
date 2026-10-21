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
