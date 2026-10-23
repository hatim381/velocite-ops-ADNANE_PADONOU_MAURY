# Postmortem - Incident de production VéloCité 2.3.0

**Date de l'incident :** nuit du 15 au 16 octobre 2026
**Périmètre :** `velocite-prod`, API VéloCité
**Gravité :** incident majeur
**Statut :** résolu

## Résumé

La livraison nocturne de la version 2.3.0 a déployé une API qui utilisait la
colonne `trajets.duree_s` alors que la migration requise n'était pas appliquée
en production, provoquant des réponses 500 sur les routes métier. L'incident a
duré de 02:05 à 02:29 et le service a été rétabli par retour arrière vers la
version 2.2.1, avant l'exécution de la migration puis la relivraison de la
version 2.3.0.

## Impact

- La durée de l'incident est de 24 minutes, de 02:05 à 02:29.
- 3 412 appels ont échoué, soit 100 % des appels sur
  cette période.
- 287 usagers distincts ont été touchés.
- Le support a reçu quatre signalements ; le premier est arrivé à 02:11.
- L'incident a consommé 24 des 432 minutes du budget mensuel d'erreur, soit
  5,6 % de ce budget (`24 / 432 × 100`, arrondi au dixième).
- Les routes `/api/stations` et `/api/trajets` ont déclenché l'alerte
  `BudgetErreurConsommeVite`.

## Chronologie

| Heure (Paris) | Événement |
| --- | --- |
| 02:00:12 | Démarrage de la livraison nocturne de la version 2.3.0. |
| 02:03:58 | Application de l'overlay de production. |
| 02:04:31 | Le rollout annonce deux pods API prêts. |
| 02:05 | Début des erreurs 500 sur les routes métier. |
| 02:11 | Premier signalement au support. |
| 02:14:05 | `BudgetErreurConsommeVite` passe en alerte sur stations et trajets ; l'astreinte est notifiée. |
| 02:16 | L'astreinte prend l'incident et commence le diagnostic. |
| 02:21 | L'incident est qualifié majeur. |
| 02:22 | Publication du premier message sur la page de statut. |
| 02:24 | Retour arrière de l'API vers la version 2.2.1. |
| 02:29 | Le rollout est terminé et les appels répondent de nouveau en 200. |
| 02:33:20 | Les alertes SLO sont résolues. |
| 02:45 | La page de statut indique que le service est rétabli. |
| 07:52 | L'absence de la migration 0012 est identifiée. |
| 09:40 | Exécution de la migration 0012 en production. |
| 09:55 | Relivraison de la version 2.3.0 et fermeture de l'incident. |

## Causes

La version 2.3.0 nécessitait la migration
`0012_trajets_duree` pour créer la colonne `trajets.duree_s` (pièce 3). Cette
migration n'a pas été exécutée avant la livraison (pièces 2 et 8). Les logs de
l'API montrent l'erreur `pq: column "duree_s" does not exist` (pièce 5), ce qui
explique les réponses 500 sur les routes qui accèdent aux trajets.

Cette cause a été rendue possible par une procédure de migration manuelle avant
la fusion dans `main`. Le workflow de livraison nocturne déploie les images,
mais n'exécute ni ne vérifie les migrations de base de données (pièces 1 et 2).
Le déploiement a été déclaré prêt (pièce 1), la sonde `/healthz` répondait
(pièces 4 et 5), puis les routes métier ont échoué parce que le schéma ne
contenait pas la colonne attendue (pièce 5).

La sonde ne vérifie qu'un serveur à l'écoute et non une requête dépendante du
schéma (pièce 4). Le rollout a donc déclaré les pods prêts avant la première
requête métier en échec (pièces 1 et 5). Aucun garde-fou automatisé ne reliait
le changelog, la migration requise et l'autorisation de livrer (pièces 2 et 3).
L'alerte SLO a ensuite détecté l'indisponibilité côté client après plusieurs
minutes de consommation du budget d'erreur (pièces 5 et 7).

## Ce qui a bien fonctionné

- L'alerte SLO a détecté et notifié l'astreinte à 02:14:05, ce qui a permis une
  prise en charge structurée de l'incident.
- L'astreinte a qualifié l'incident, l'a communiqué aux usagers à 02:22, puis a
  effectué le retour arrière à 02:24 sans attendre une analyse complète.
- Le retour arrière vers la version 2.2.1 a rétabli les réponses 200 à 02:29.

## Actions

| Action | Responsable | Échéance |
| --- | --- | --- |
| Ajouter au pipeline un contrôle bloquant qui vérifie les migrations requises avant le déploiement. | Équipe API | 29 octobre 2026. |
| Remplacer la procédure manuelle par une étape versionnée, traçable et validée dans la livraison. | Équipe API et exploitation | 29 octobre 2026. |
| Ajouter un smoke test post-déploiement qui exécute une requête métier dépendante du schéma. | Équipe exploitation | 29 octobre 2026. |
| Ajouter une checklist de livraison liant version, changelog et migrations requises. | Équipe API | 29 octobre 2026. |
| Rejouer un exercice de retour arrière et vérifier le message de statut. | Équipe exploitation | 29 octobre 2026. |

## Annexe A - Le prompt utilisé

> Tu es responsable d'exploitation et tu rédiges pour l'équipe VéloCité un
> postmortem d'apprentissage, sans blâmer de personne. Utilise exclusivement le
> dossier fourni : n'invente aucun fait, date, responsable, mesure ou cause, et
> indique toute incertitude. Rédige exactement les six sections suivantes, dans
> cet ordre : Résumé en deux phrases ; Impact chiffré ; Chronologie ; Causes ;
> Ce qui a bien fonctionné ; Actions. Pour chaque cause, cite la ou les pièces
> du dossier qui l'appuient. Les actions proposées doivent avoir un responsable
> d'équipe et une date. Le dossier d'incident est collé intégralement juste
> après ce prompt. Distingue toujours les faits observés des propositions.

Le dossier utilisé est `Dossier_Incident_2.3.0.md`.

## Annexe B - Ce que j'ai vérifié

| Affirmation vérifiée | Pièce | Résultat |
| --- | --- | --- |
| La version 2.3.0 a été déployée par la livraison nocturne et les pods étaient déclarés prêts à 02:04:31. | Pièce 1 | Juste : aucune correction. |
| La version 2.3.0 nécessitait la migration `0012_trajets_duree` avant sa mise en service. | Pièce 3 | Juste : aucune correction. |
| L'API a échoué parce que la colonne `duree_s` n'existait pas. | Pièce 5 | Juste : aucune correction. |
| Les pods étaient Ready bien que les requêtes métier échouent. | Pièces 4, 5 et 8 | Juste : aucune correction. |
| L'alerte SLO a été déclenchée à 02:14:05 sur stations et trajets. | Pièce 7 | Juste : aucune correction. |
| L'incident a duré 24 minutes et consommé 5,6 % du budget mensuel d'erreur. | Pièce 9, avec calcul `24 / 432 × 100` | Corrigé : pourcentage arrondi au dixième. |
| Les personnes ne sont pas désignées comme responsables de la cause. | Pièces 2, 3 et 5 | Juste : aucune correction. |
| Le retour arrière a été lancé à 02:24 et le service a répondu de nouveau en 200 à 02:29. | Pièces 6 et 8 | Juste : aucune correction. |
| 3 412 appels ont échoué et 287 usagers distincts ont été touchés. | Pièce 9 | Juste : aucune correction. |
| La migration a été exécutée à 09:40 et la 2.3.0 relivrée à 09:55. | Pièces 6 et 8 | Juste : aucune correction. |
