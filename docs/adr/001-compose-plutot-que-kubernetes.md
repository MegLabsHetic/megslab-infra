# ADR 001 — Docker Compose plutôt que Kubernetes en production

- **Statut** : accepté
- **Date** : 2026-08-24

## Contexte

MegLabs tourne sur un serveur unique — OVH VPS-4, 8 vCPU, 24 Go, Roubaix — et sert deux
environnements (production et préproduction) pour un total de six conteneurs. L'équipe doit
démontrer des compétences d'ingénierie d'exploitation lors d'une soutenance.

La tentation était d'installer Kubernetes, qui est l'orchestrateur attendu par réflexe dès qu'on
parle de conteneurs.

## Options envisagées

**Kubernetes complet (kubeadm, ou distribution managée).** Écarté sur la mesure ci-dessous et sur
le coût d'exploitation : un plan de contrôle à surveiller, des manifests à écrire, un mode de
panne supplémentaire, pour une charge qui tient dans un seul processus par service.

**k3s.** Plus léger, réellement viable sur un serveur unique. Écarté en production pour la même
raison de fond — aucune fonction de Kubernetes n'est utilisée ici : ni montée en charge
horizontale, ni tolérance de panne d'un nœud, ni déploiement progressif entre plusieurs machines.
Retenu en revanche comme **démonstration du chemin de migration** (voir Conséquences).

**Docker Compose.** Retenu.

## Ce qui a tranché

La plateforme Airbyte a été déployée en local via `abctl`, qui monte un cluster Kubernetes (kind).
Mesure relevée sur la machine de développement, cluster au repos, aucune synchronisation en cours :

```
airbyte-abctl-control-plane   5,417 Gio / 7,577 Gio   CPU 292,87 %
```

Décompte des conteneurs à l'intérieur du cluster : **18 au total**, dont **9 pour le seul plan de
contrôle Kubernetes** (etcd, apiserver, controller-manager, scheduler, kube-proxy, kindnet, deux
coredns, local-path-provisioner) et 1 pour l'ingress. Huit conteneurs sur dix-huit faisaient le
travail demandé.

Le plan de contrôle consommait à lui seul environ 1 Go de mémoire, et `kube-controller-manager` en
était à sa septième tentative de démarrage, `kube-scheduler` à sa sixième — le cluster était sous
pression avant même de servir.

En regard, la pile applicative complète — deux backends, deux frontends, PostgreSQL, reverse proxy
— tient sous 4,6 Go avec des limites mémoire explicites.

## Décision

La production tourne sur Docker Compose. Un seul fichier décrit les six services, leurs limites
mémoire, leurs réseaux et leurs sondes de santé.

## Conséquences

**Ce qu'on gagne.** Un fichier lisible en une fois, aucun composant d'orchestration à exploiter,
une empreinte mémoire dédiée à l'application. Le budget mémoire est explicite et vérifiable.

**Ce qu'on perd.** Pas de redémarrage automatique sur une autre machine si le serveur tombe — le
serveur *est* le point de défaillance unique, assumé à cette échelle. Pas de déploiement progressif :
un `up -d` remplace le conteneur, avec une coupure de quelques secondes couverte par la sonde de
santé.

**Ce qui reste ouvert.** Des manifests k3s équivalents sont maintenus dans ce dépôt à titre de
démonstration du chemin de migration, et déployés une fois pour prouver qu'ils fonctionnent. Le
seuil qui justifierait la bascule : une seconde machine, ou un besoin de déploiement sans coupure.

**Ce qu'il faut surveiller.** Si le rejeu des actions de nettoyage ou une synchronisation de
connecteur dépasse durablement les limites mémoire fixées, c'est le dimensionnement qu'il faut
revoir en premier, pas l'orchestrateur.
