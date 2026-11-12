# KTaskWidget — Générer et installer le widget (Kubuntu / Ubuntu 26.04 LTS, Plasma 6)

Ce widget est un plasmoid **100 % QML/JavaScript** : il n'y a **pas de compilation**. Plasma interprète le QML au chargement. « Générer » le widget signifie simplement **empaqueter** le dossier source dans une archive `.plasmoid` (un zip avec une structure précise), ou l'installer directement depuis le dossier source avec `kpackagetool6`.

> **Version cible** : Ubuntu 26.04.1 LTS avec le bureau KDE Plasma 6 (testé sur Plasma 6.6.6, Qt 6, KDE Frameworks 6).
> La version Plasma 5 (Kubuntu 24.04 et antérieurs) n'est plus supportée depuis la v0.2 — voir [§10](#10-migration-depuis-la-version-plasma-5).

Sommaire :

1. [Prérequis](#1-prérequis)
2. [Récupérer les sources](#2-récupérer-les-sources)
3. [Installation rapide](#3-installation-rapide)
4. [Ajouter le widget au panneau ou au bureau](#4-ajouter-le-widget-au-panneau-ou-au-bureau)
5. [Générer l'archive `.plasmoid`](#5-générer-larchive-plasmoid)
6. [Installer l'archive `.plasmoid`](#6-installer-larchive-plasmoid)
7. [Vérifier l'installation](#7-vérifier-linstallation)
8. [Mettre à jour le widget](#8-mettre-à-jour-le-widget)
9. [Désinstaller](#9-désinstaller)
10. [Migration depuis la version Plasma 5](#10-migration-depuis-la-version-plasma-5)
11. [Développement](#11-développement)
12. [Dépannage](#12-dépannage)
13. [Référence des cibles `make`](#13-référence-des-cibles-make)

---

## 1. Prérequis

| Outil | Vérification | Paquet Ubuntu 26.04 | Utilité |
| --- | --- | --- | --- |
| **KDE Plasma 6** | `plasmashell --version` → `plasmashell 6.x` | `kubuntu-desktop` (déjà présent sur Kubuntu) | Exécute le widget |
| **kpackagetool6** | `which kpackagetool6` | `kpackagetool6` | Installe / met à jour / supprime le widget |
| **make** | `which make` | `make` | Raccourcis de build/installation |
| **zip** | `which zip` | `zip` | Création de l'archive `.plasmoid` |
| **python3** | `which python3` | `python3` (présent par défaut) | Validation de `metadata.json` (`make check`) |
| **plasmoidviewer** *(optionnel, dev)* | `which plasmoidviewer` | `plasma-sdk` | Lancer le widget dans une fenêtre isolée |

Installation en une ligne :

```sh
sudo apt update
sudo apt install kpackagetool6 make zip
# Optionnel, uniquement pour développer :
sudo apt install plasma-sdk
```

Vérifiez que vous êtes bien sous Plasma 6 :

```sh
plasmashell --version     # doit afficher : plasmashell 6.x.y
```

> Sous Ubuntu « standard » (GNOME), ce widget ne fonctionne pas : il nécessite une session KDE Plasma (Kubuntu, ou `sudo apt install kubuntu-desktop` puis choix de la session « Plasma » à l'écran de connexion).

---

## 2. Récupérer les sources

```sh
git clone <url-du-dépôt> KTaskWidget
cd KTaskWidget
```

Structure du dépôt :

```
KTaskWidget/
├── Makefile                         cibles build / install / dev
├── README.md
├── docs/
│   ├── INSTALL.md                   ce document
│   └── IMPLEMENTATION.md            architecture technique
└── package/
    └── org.kde.ktaskwidget/         le plasmoid lui-même
        ├── metadata.json            manifeste Plasma 6
        └── contents/
            ├── config/main.xml      schéma de configuration (stockage des tâches)
            └── ui/
                ├── main.qml         racine (PlasmoidItem), modèle et logique CRUD
                ├── FullRepresentation.qml   popup : barre d'outils + liste
                └── TaskRow.qml      ligne d'une tâche
```

---

## 3. Installation rapide

Depuis la racine du dépôt, **dans un terminal Konsole** (voir [§12](#install-réussie-mais-widget-invisible-piège-du-terminal-snap) si vous utilisez le terminal de VS Code) :

```sh
make check      # vérifie la structure du paquet (facultatif)
make install    # installe ou met à jour le widget
```

`make install` est idempotent :

- si le widget n'est pas installé → `kpackagetool6 --type Plasma/Applet --install package/org.kde.ktaskwidget`
- s'il est déjà installé → `kpackagetool6 --type Plasma/Applet --upgrade package/org.kde.ktaskwidget`
- s'il reste une ancienne copie **Plasma 5** (non reconnue par `kpackagetool6`) → elle est supprimée puis remplacée.

Les fichiers sont copiés dans :

```
~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/
```

Lors d'une **première** installation, le widget apparaît immédiatement dans le sélecteur de widgets, sans redémarrer Plasma.

---

## 4. Ajouter le widget au panneau ou au bureau

1. Clic droit sur le panneau (ou sur le bureau) → **Ajouter des composants graphiques…** (*Add Widgets…*).
2. Dans la barre latérale qui s'ouvre, recherchez **Task Widget**.
3. Glissez-déposez l'entrée sur le panneau ou le bureau (ou double-cliquez dessus).

Utilisation :

- Clic sur l'icône → ouvre / ferme la liste des tâches.
- **+** : ajouter une tâche (Entrée pour valider, Échap pour annuler).
- Case à cocher : marquer comme faite (la tâche descend en bas de la liste, barrée).
- Double-clic sur le nom ou icône crayon : renommer.
- Corbeille : supprimer une tâche ; icône « vider la liste » : supprimer toutes les tâches terminées.
- Poignée **⋮⋮** à gauche : glisser pour réordonner.

---

## 5. Générer l'archive `.plasmoid`

Pour distribuer le widget à quelqu'un qui n'a pas les sources ni `make` :

```sh
make package
```

Cela produit `ktaskwidget.plasmoid` à la racine du dépôt. En coulisses :

```sh
cd package/org.kde.ktaskwidget && zip -r ../../ktaskwidget.plasmoid . -x "*.bak" "*~"
```

**Important** : `metadata.json` doit se trouver **à la racine** de l'archive, pas dans un sous-dossier. Vérifiez avec :

```sh
unzip -l ktaskwidget.plasmoid
```

La liste doit contenir `metadata.json` et `contents/...`, **pas** `org.kde.ktaskwidget/metadata.json`.

La cible ne reconstruit l'archive que si un fichier source a changé. Pour forcer : `make clean package`.

---

## 6. Installer l'archive `.plasmoid`

### 6.1 Via l'interface graphique de Plasma

1. Clic droit sur le bureau ou un panneau → **Ajouter des composants graphiques…**
2. En haut de la barre latérale, cliquez sur **Obtenir de nouveaux composants graphiques** → **Installer un composant graphique depuis un fichier local…**
3. Sélectionnez `ktaskwidget.plasmoid`.
4. Une confirmation s'affiche ; **Task Widget** est maintenant disponible dans la liste (voir [§4](#4-ajouter-le-widget-au-panneau-ou-au-bureau)).

### 6.2 En ligne de commande

```sh
kpackagetool6 --type Plasma/Applet --install ktaskwidget.plasmoid
# ou, si une version est déjà installée :
kpackagetool6 --type Plasma/Applet --upgrade ktaskwidget.plasmoid
```

`kpackagetool6` accepte indifféremment un dossier ou une archive `.plasmoid`.

---

## 7. Vérifier l'installation

```sh
kpackagetool6 --type Plasma/Applet --list | grep ktaskwidget
# → org.kde.ktaskwidget

kpackagetool6 --type Plasma/Applet --show org.kde.ktaskwidget
# → Name: Task Widget, Path: /home/<vous>/.local/share/plasma/plasmoids/org.kde.ktaskwidget/

ls ~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/
# → contents  metadata.json
```

Le chemin affiché par `--show` doit être sous `~/.local/share/`, **pas** sous `~/snap/...`.

---

## 8. Mettre à jour le widget

Les fichiers sur disque et l'instance qui tourne dans `plasmashell` sont deux choses distinctes : il faut mettre à jour les deux.

### Étape 1 — mettre à jour les fichiers

```sh
git pull          # si besoin
make install      # fait un --upgrade si déjà installé
```

### Étape 2 — recharger Plasma

`plasmashell` garde en mémoire le QML déjà chargé. Retirer puis réajouter le widget **ne suffit pas** à charger le nouveau code. Il faut redémarrer `plasmashell` :

```sh
make restart
# équivalent à : systemctl --user restart plasma-plasmashell.service
```

Le panneau et le bureau disparaissent environ une seconde, puis reviennent. Les fenêtres ouvertes ne sont pas affectées.

Alternative si `systemctl` ne convient pas : `kquitapp6 plasmashell && kstart plasmashell`, ou simplement se déconnecter / se reconnecter.

### Étape 3 — vérifier

```sh
make logs
```

suit le journal de `plasmashell` filtré sur `ktaskwidget`. Aucune ligne d'erreur ne doit apparaître à l'ouverture du widget.

**Vos tâches sont conservées** lors des mises à jour : elles sont stockées dans la configuration Plasma (voir [§9](#9-désinstaller)), pas dans les fichiers du paquet.

---

## 9. Désinstaller

1. Retirez d'abord le widget du panneau : clic droit sur l'icône → **Supprimer** (*Remove*). Cela efface aussi ses tâches.
2. Puis supprimez le paquet :

```sh
make remove
# équivalent à : kpackagetool6 --type Plasma/Applet --remove org.kde.ktaskwidget
```

Si vous désinstallez le paquet **sans** retirer le widget du panneau, les tâches restent dans `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (clé `tasksJson`) et réapparaîtront si vous réinstallez.

### Sauvegarder ses tâches

```sh
grep tasksJson ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

affiche la liste des tâches au format JSON. Copiez ce fichier pour une sauvegarde complète.

---

## 10. Migration depuis la version Plasma 5

Si vous passez d'une Kubuntu antérieure (Plasma 5) à Ubuntu 26.04 (Plasma 6) :

- L'ancien paquet installé (`~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/` contenant `metadata.desktop`) n'est **plus reconnu** par Plasma 6 : le widget apparaît alors en erreur ou vide sur le panneau, et `kpackagetool6 --upgrade` répond « Plugin org.kde.ktaskwidget is not installed ».
- Il suffit de lancer, depuis ce dépôt à jour :

  ```sh
  make install    # détecte et remplace la copie Plasma 5
  make restart
  ```

- L'identifiant du plugin (`org.kde.ktaskwidget`) et la clé de configuration (`tasksJson`) sont inchangés : **le widget déjà placé sur le panneau et ses tâches sont conservés**.

Résumé des changements techniques de la v0.2 (détails dans [IMPLEMENTATION.md](IMPLEMENTATION.md#7-plasma-6-port-notes)) :

| Plasma 5 (v0.1) | Plasma 6 (v0.2) |
| --- | --- |
| `metadata.desktop` | `metadata.json` |
| `kpackagetool5` | `kpackagetool6` |
| Racine `Item` + propriétés attachées `Plasmoid.*` | Racine `PlasmoidItem` |
| `PlasmaCore.Units`, `PlasmaCore.Theme` | `Kirigami.Units`, `Kirigami.Theme` |
| `PlasmaCore.IconItem` | `Kirigami.Icon` |
| `kquitapp5 plasmashell && kstart5 plasmashell` | `systemctl --user restart plasma-plasmashell.service` |

---

## 11. Développement

Boucle de développement la plus rapide (nécessite `plasma-sdk`) :

```sh
make dev
# équivalent à : plasmoidviewer --applet package/org.kde.ktaskwidget
```

`plasmoidviewer` charge le widget directement depuis le dossier source dans une fenêtre séparée : chaque relance relit le QML, sans installation ni redémarrage de Plasma. Les erreurs QML s'affichent dans le terminal.

Pour tester dans le vrai panneau :

```sh
make install restart
make logs
```

Test manuel recommandé après chaque modification :

1. Ouvrir le widget → « No tasks yet » sur une liste vide.
2. **+**, saisir une tâche, Entrée → la tâche apparaît.
3. Cocher → la tâche est barrée et descend en bas.
4. Double-cliquer le nom → édition, Entrée → nom mis à jour ; Échap → annulation.
5. Glisser une tâche par sa poignée → l'ordre change.
6. Bouton « vider » → les tâches terminées disparaissent.
7. `make restart` → les tâches sont toujours là.

---

## 12. Dépannage

### « Task Widget » n'apparaît pas dans la liste des widgets

1. `kpackagetool6 --type Plasma/Applet --list | grep ktaskwidget` — si absent, relancez `make install` et lisez les erreurs.
2. `make check` — vérifie que `metadata.json` est un JSON valide.
3. `make restart`.

### Le widget affiche une icône d'erreur ou un message « … could not be loaded »

Le QML ne se charge pas. Pour voir l'erreur :

```sh
make dev                                  # si plasma-sdk est installé
# ou
journalctl --user -b -o cat | grep -i ktaskwidget
```

Cause la plus fréquente après une mise à niveau d'Ubuntu : l'ancienne copie Plasma 5 est encore installée → voir [§10](#10-migration-depuis-la-version-plasma-5).

### `Error: Plugin org.kde.ktaskwidget is not installed.` lors d'un `--upgrade`

Le dossier existe mais contient une version Plasma 5 que `kpackagetool6` ne reconnaît pas. Utilisez `make install` (qui gère ce cas) ou supprimez manuellement `~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/` puis réinstallez.

### Les modifications du code ne sont pas prises en compte

Vous avez oublié de redémarrer `plasmashell` : `make restart` (voir [§8](#8-mettre-à-jour-le-widget)).

### Les tâches ne sont pas sauvegardées

```sh
grep -A1 tasksJson ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

Si la clé est absente après avoir ajouté une tâche, vérifiez que `contents/config/main.xml` est présent dans le paquet installé, puis `make reinstall restart`. La sauvegarde est différée de 500 ms après chaque modification.

### L'archive `.plasmoid` est refusée par l'installation graphique

Structure incorrecte : `unzip -l ktaskwidget.plasmoid` doit montrer `metadata.json` à la racine. Reconstruisez avec `make clean package`.

### `kpackagetool6: command not found`

```sh
sudo apt install kpackagetool6
```

### Install réussie mais widget invisible (piège du terminal snap)

Si `make` / `kpackagetool6` est lancé depuis le terminal intégré de **VS Code installé en snap**, la variable `XDG_DATA_HOME` pointe vers `~/snap/code/<rev>/.local/share`, un dossier que Plasma ne lit jamais. Le `Makefile` force `XDG_DATA_HOME=$HOME/.local/share` pour éviter ce piège. Si vous appelez `kpackagetool6` à la main depuis un tel terminal :

```sh
XDG_DATA_HOME=$HOME/.local/share kpackagetool6 --type Plasma/Applet --install package/org.kde.ktaskwidget
```

De même, `make restart` doit de préférence être lancé depuis Konsole.

---

## 13. Référence des cibles `make`

| Cible | Action |
| --- | --- |
| `make help` | Liste les cibles |
| `make check` | Vérifie la présence de `metadata.json` (JSON valide), `main.qml` et `main.xml` |
| `make package` | Génère `ktaskwidget.plasmoid` |
| `make install` | Installe, ou met à jour si déjà installé (remplace une copie Plasma 5) |
| `make upgrade` | `kpackagetool6 --upgrade` uniquement |
| `make remove` | Désinstalle le paquet |
| `make reinstall` | `remove` puis `install` |
| `make restart` | Redémarre `plasmashell` pour charger le nouveau code |
| `make dev` | Lance le widget dans `plasmoidviewer` |
| `make logs` | Suit le journal de `plasmashell` filtré sur le widget |
| `make clean` | Supprime l'archive générée |
