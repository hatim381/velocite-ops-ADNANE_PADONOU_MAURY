# Paramètres de la plateforme

A FAIRE, mardi et mercredi. Tout ce qui se règle, l'endroit où on le règle,
les écarts entre dev et prod. Règle : un paramètre a un seul endroit où on
le modifie.

## Couche 00 - le cluster

| Variable | Défaut | Rôle |
|---|---|---|
| | | |

## Couche 10 - les outils

## Couche 20 - un environnement

| Variable | dev | prod | Rôle |
|---|---|---|---|
| `env` | `dev` | `prod` | Choisit le namespace et doit correspondre au workspace OpenTofu. |
| `quota.cpu_demande` | `2` | `3` | Plafond cumulé des demandes CPU. |
| `quota.memoire_limite` | `4Gi` | `6Gi` | Plafond cumulé des limites mémoire. |
| `quota.stockage` | `10Gi` | `20Gi` | Stockage persistant maximal demandé. |
| `quota.nb_pvc` | `6` | `6` | Nombre maximal de revendications de volumes persistants. |
| `quota.nb_pods` | `30` | `40` | Nombre maximal de pods dans le namespace. |

## Les secrets

| Secret Kubernetes | Clés | Lu par |
|---|---|---|
| `velocite-db` | mots de passe PostgreSQL et URL de connexion par service | PostgreSQL, API, ingest, batch, initialisation |
| `velocite-app` | mots de passe des comptes, JWT, clé d'ingestion et clé de pseudonymisation | API, ingest, loadgen, initialisation, batch |
| `velocite-redis` | ACL Redis, sonde et URL API | Redis et API |
| `velocite-garage` | jetons Garage et clés S3 | Garage, API, batch et initialisation |
| `velocite-tls-nginx` | `tls.crt`, `tls.key` | nginx |
| `velocite-tls-postgres` | `postgres.crt`, `postgres.key` | PostgreSQL |

## Les applications

| Paramètre | dev | prod | Où |
|---|---|---|---|
| | | | |

## Le bilan quotidien

| Paramètre | Valeur | Où | Rôle |
|---|---|---|---|
| Calendrier | `30 2 * * *` | `workflows/cron-bilan.yaml` | Lance le bilan chaque jour à 02:30. |
| Fuseau horaire | `Europe/Paris` | `workflows/cron-bilan.yaml` | Suit automatiquement les changements d'heure. |
| Chevauchement | `Forbid` et mutex `bilan-quotidien` | CronWorkflow et WorkflowTemplate | Empêche deux bilans simultanés, y compris un lancement manuel. |
| Rattrapage | `3600` secondes | `workflows/cron-bilan.yaml` | Rattrape un lancement manqué pendant une heure au plus. |
| Durée maximale | `1800` secondes | `workflows/bilan-quotidien.yaml` | Met fin à un bilan bloqué, qui est alors signalé. |
| Relances | 3 essais, code 75 seulement | `workflows/bilan-quotidien.yaml` | Réessaie les pannes temporaires après 30 s, 60 s puis 120 s. |
| Injection de panne | `BATCH_FAIL_RATE="0"` | `workflows/bilan-quotidien.yaml` | Reste désactivée hors exercice de relance. |
| Conservation Argo | 2 succès, 4 échecs | `workflows/cron-bilan.yaml` | Garde un historique court pour l'enquête. |

## Les alertes
