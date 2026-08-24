# megslab-infra

Configuration des serveurs qui font tourner [MegLabs](https://github.com/MegLabsHetic/meglabs).

**Ce dépôt prépare les machines. Il ne déploie pas l'application** — le dépôt applicatif est
seul à connaître ses images, ses variables et ses migrations. La frontière est volontaire : une
machine se configure rarement, une application se déploie plusieurs fois par jour.

## Les trois couches, et pourquoi elles sont séparées

| Couche | Outil | Ce qu'elle fait | Fréquence |
|---|---|---|---|
| Provisionnement | OpenTofu | Le serveur, les zones DNS | rare |
| **Configuration** | **Ansible** | Comptes, SSH, pare-feu, Docker | occasionnelle |
| Déploiement | Compose + CI *(dépôt applicatif)* | L'application | continue |

Un script bash fait le travail une fois. Ansible est **idempotent** : on le relance, rien ne
change. C'est cette propriété qui permet de vérifier qu'un serveur est conforme sans le modifier,
et de reconstruire une machine détruite à l'identique.

## Utilisation

Ansible ne tourne pas nativement sous Windows. Le plus simple est de le lancer dans un conteneur,
ce qui évite aussi les écarts de version entre postes :

```bash
docker run --rm -it \
  -v "$PWD/ansible:/ansible" -v "$HOME/.ssh:/root/.ssh:ro" \
  -w /ansible alpine/ansible \
  ansible-playbook site.yml --check --diff
```

`--check --diff` **ne modifie rien** et affiche exactement ce qui changerait. C'est la commande à
lancer en premier, et celle qui sert d'audit de conformité : une sortie sans changement signifie
que le serveur est conforme à ce dépôt.

Pour appliquer, retirer `--check --diff`.

Sans Docker, avec WSL ou Linux :

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --check --diff
```

## Ce que le playbook garantit

- Un compte de service `meglabs`, **hors du groupe sudo** : il fait tourner des conteneurs, il
  n'administre pas la machine
- SSH par clé uniquement — ni mot de passe, ni connexion root, trois tentatives maximum
- Pare-feu fermé par défaut, seuls 22, 80 et 443 ouverts
- `fail2ban` sur sshd, bannissement d'une heure après quatre échecs
- Mises à jour de sécurité automatiques
- Docker depuis le dépôt officiel signé, avec rotation des journaux de conteneurs
- Journaux système bornés à 500 Mo

Le rôle `securite` **vérifie son propre travail** : il relit la configuration effective avec
`sshd -T` et échoue si l'authentification par mot de passe est encore acceptée. Appliquer n'est
pas la même chose qu'être effectif — `sshd_config.d` est lu en tête et la première occurrence d'un
mot-clé gagne, donc un fichier déposé par cloud-init peut annuler le durcissement sans rien
signaler.

## Structure

```
ansible/
├── inventory.yml            les machines, et rien d'autre
├── group_vars/all.yml       les variables partagées
├── site.yml                 le playbook principal
└── roles/
    ├── base/                comptes, paquets, mises à jour, journaux
    ├── securite/            SSH, ufw, fail2ban
    └── docker/              dépôt officiel, daemon, groupe
opentofu/                    DNS et ressources pilotables chez OVH
docs/adr/                    les décisions et ce qui les a tranchées
```

## Décisions

Les arbitrages sont dans [docs/adr/](docs/adr/). Chacune dit le contexte, les options écartées et
**la mesure qui a tranché** — pas seulement le choix retenu.
