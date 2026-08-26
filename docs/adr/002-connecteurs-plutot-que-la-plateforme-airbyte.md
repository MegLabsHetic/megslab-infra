# ADR 002 — Les connecteurs Airbyte, pas la plateforme Airbyte

- **Statut** : accepté
- **Date** : 2026-08-25

## Contexte

MegLabs doit pouvoir lire des bases, des CRM, des ERP et des outils de vente. Écrire un client
par système coûterait des semaines : OAuth, pagination, curseurs incrémentaux, limites de débit,
et une maintenance par API.

Airbyte propose environ trois cents connecteurs déjà écrits et maintenus. La question n'était donc
pas *faut-il les utiliser* mais *à quel niveau les brancher*.

## Options envisagées

**La plateforme Airbyte complète**, déployée par `abctl`. Écartée — voir les trois mesures.

**Les connecteurs seuls**, lancés directement comme des processus. Retenue.

**Écrire nos propres clients.** Écartée : plusieurs jours par source, pour un résultat moins
maintenu que ce qui existe.

## Ce qui a tranché

Trois arguments indépendants convergent, ce qui est rare.

### L'empreinte, mesurée

La plateforme a été déployée en local via `abctl`, puis une synchronisation Jira réussie.
Relevé sur la machine de développement, cluster **au repos**, aucune synchronisation en cours :

```
airbyte-abctl-control-plane   5,417 Gio / 7,577 Gio   CPU 292,87 %
```

**Dix-huit conteneurs** à l'intérieur du cluster, dont **neuf pour le seul plan de contrôle
Kubernetes** et un pour l'ingress. Huit sur dix-huit faisaient le travail demandé. Le disque :
14,4 Go d'images, 14,1 Go de volumes, 4,5 Go de cache — environ **33 Go**.

Un connecteur lancé seul tient dans **un processus** et quelques centaines de mégaoctets.

### La licence

Le cœur de plateforme d'Airbyte est sous **Elastic License 2.0**. Sa première limitation :

> You may not provide the software to third parties as a hosted or managed service, where the
> service provides users with access to any substantial set of the features or functionality of
> the software.

MegLabs se destine à un modèle SaaS, avec une instance par client et une interface où l'utilisateur
configure ses sources. **C'est le cas explicitement interdit.**

Les images de connecteurs, elles, sont sous **MIT**. Le même travail, sans la restriction — et le
droit d'habiller l'interface à nos couleurs, ce que la clause sur les marques et les mentions
interdit par ailleurs pour la plateforme.

*Réserve : cette lecture est celle d'une équipe technique, pas d'un juriste. Pour un projet
d'école le risque est nul ; l'enjeu est de savoir répondre à la question.*

### Ce que ça vaut à l'oral

« On a installé Airbyte » décrit une installation. « On a implémenté le protocole des connecteurs,
c'est pourquoi on branche ces sources aujourd'hui et n'importe laquelle des centaines existantes
demain » décrit une architecture — et se défend ligne à ligne.

## Décision

MegLabs implémente le protocole des connecteurs dans `app/core/connecteur.py`. Un connecteur est
un programme qui écrit du JSON ligne par ligne sur sa sortie standard ; l'adaptateur parle les deux
dialectes (Singer et Airbyte), rend des DataFrames, et le pipeline existant travaille ensuite sans
savoir d'où vient la table.

La plateforme reste installable par le rôle Ansible `airbyte`, marqué `never` : elle sert
**l'exploration interne**, jamais la production, et jamais un client.

## Conséquences

**Ce qu'on gagne.** Un facteur dix sur la mémoire. Une interface qui est la nôtre. Un modèle
économique licite. Et l'indépendance vis-à-vis d'un fournisseur : un tap Singer et une image
Airbyte sont la même chose vue du code.

**Ce qu'on perd.** La planification, l'historique des exécutions et les reprises automatiques, que
la plateforme fournit. Nous les écrivons ou nous nous en passons. Surtout : **les flux OAuth**,
qu'Airbyte gère pour les sources SaaS. La parade retenue est de commencer par des sources à jeton
— PostgreSQL, Jira, Odoo, Stripe — qui n'en demandent pas.

**Un risque de sécurité créé par ce choix.** Lancer une image de connecteur depuis le backend
impose de monter le socket Docker, ce qui équivaut à donner root sur l'hôte à un service qui
exécute par ailleurs du SQL écrit par un modèle de langage. C'est pourquoi **les taps Singer sont
préférés** : ce sont des paquets Python, donc un simple sous-processus, sans élévation. Les images
Airbyte n'entreront en jeu que derrière un worker isolé, si le besoin se présente.

**Ce qu'il faut surveiller.** La qualité des taps communautaires est inégale. Aucun connecteur ne
doit entrer dans une démonstration sans avoir été exécuté au moins une fois de bout en bout.
