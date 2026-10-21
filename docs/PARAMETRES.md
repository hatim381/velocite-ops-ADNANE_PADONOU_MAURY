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

## Les alertes
