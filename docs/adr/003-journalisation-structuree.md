# ADR 003 — Journalisation structurée, corrélée par requête

- **Statut** : accepté
- **Date** : 2026-08-26

## Contexte

L'application n'écrivait **aucun log**. `grep -r "import logging" backend/app` ne rendait rien.
`LOG_LEVEL` était lu dans les réglages et jamais appliqué. Le modèle `LlmCallLog` existait en base
et n'était jamais écrit.

Ce n'est pas resté théorique. Le 26 août, après une bascule de fournisseur de modèle, trois
questions ont échoué d'affilée en production. Les journaux du conteneur ne contenaient que des
lignes d'accès uvicorn :

```
INFO:     172.18.0.2:47706 - "POST /api/chat/bc3fb04... HTTP/1.1" 200 OK
```

Le diagnostic a imposé de tester la clé du fournisseur contre son API à la main, depuis un poste de
développement, avec les identifiants de production. La cause — un solde de crédit épuisé — était à
une ligne de log près.

## Options envisagées

**Des logs texte.** Écartés : lisibles par un humain, pénibles pour un collecteur, et le filtrage
repose alors sur des expressions régulières qui cassent au premier changement de format.

**OpenTelemetry.** Écarté pour l'instant : traces distribuées, exportateur, collecteur — plusieurs
jours pour un système qui tient sur une machine et six conteneurs. Le besoin immédiat est de savoir
*pourquoi* une requête a échoué, pas de suivre un appel entre douze services.

**Du JSON structuré sur la sortie standard.** Retenu.

## Décision

Un module `app/core/journal.py` : un formateur JSON, un identifiant de requête, un filtre de clés
sensibles.

**Du JSON, une ligne par événement.** `docker logs` reste lisible, `jq` filtre sans expression
régulière, et un collecteur — Loki plus tard — ingère sans adaptateur.

**Sur la sortie standard.** Docker capture stdout ; écrire ailleurs produirait des journaux que le
conteneur n'expose pas. La rotation est déléguée au démon Docker, configurée par le rôle Ansible
`docker` à 10 Mo × 3 par conteneur.

**Un identifiant de requête propagé par `contextvars`.** La chaîne d'agents est asynchrone et
traverse une dizaine de fonctions ; passer l'identifiant en paramètre à chacune polluerait toutes
les signatures pour un besoin purement technique. Il est renvoyé au client dans l'en-tête
`X-Request-ID` : une erreur signalée par un utilisateur se retrouve par une recherche, pas par un
horodatage approximatif.

**Trois points d'observation, choisis parce qu'ils sont des passages obligés** — et non parce
qu'ils semblaient intéressants :

| Point | Ce qu'il garantit |
|---|---|
| Le middleware HTTP | Aucune requête n'échappe au journal |
| `LlmClient._tracer` | Aucun appel au modèle n'échappe au compte |
| `GardeFouSql.verifier` | Aucun refus n'est perdu |

## Conséquences

**Ce qu'on gagne.** Une panne laisse une trace. Le coût et la latence de chaque appel au modèle
sont mesurables a posteriori, pas seulement affichés à l'écran. Une seconde tentative sort en
`WARNING` : la dérive d'un prompt se voit sans être cherchée.

**Les refus du garde-fou deviennent démontrables.** L'audit le relevait : on affirmait que le
garde-fou protège sans jamais pouvoir montrer qu'il avait refusé quoi que ce soit. Une protection
qu'on ne peut pas prouver ne vaut pas grand-chose devant quelqu'un qui doute.

**Ce qu'on assume.** Le filtre de clés sensibles est une **liste fermée** — `api_key`, `password`,
`mot_de_passe`, `token`, `secret`, `authorization`. Une clé nommée autrement passerait. Le filtre
est placé dans le formateur et non chez l'appelant, délibérément : une règle qui repose sur la
discipline de celui qui écrit finit par céder, et un secret journalisé est un secret divulgué — les
journaux se copient, se transmettent, et survivent au serveur qui les a produits. Un test par clé
verrouille la liste actuelle.

**Ce qui reste ouvert.** `LlmCallLog` n'est toujours pas écrit : `LlmClient` n'a pas de session de
base de données, et lui en donner une le coupleraient à la persistance. La trace part dans le
journal et dans `ChatMessage.agent_trace` ; l'écriture en base mérite une décision séparée.

La durée journalisée pour une requête de conversation ne mesure que l'ouverture du flux, pas le
temps de streaming — les Server-Sent Events rendent la main immédiatement. Le temps réel se lit
dans les événements d'agents, pas dans la ligne de requête.
