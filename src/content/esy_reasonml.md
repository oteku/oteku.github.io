+++
title = "ReasonML : Outillage d'un projet" 
date = 2020-03-23
draft = false
[taxonomies]
tags = ["ReasonML", "Tooling"]
+++

ReasonML natif dispose d'un outillage exceptionnel, grâce à l'ecosystème OCaml. Dans ce billet, je vous propose de créer depuis 0 un projet ReasonML natif. Nous parcourerons l'outillage de gestion de dépendance, de construction logicielle, de travail dans un bac à sable par projet.

<!-- more -->

> Ce billet est le troisième de la série d'articles [ReasonML : la série](../reasonml-serie/#un-programme-reason-able)

# Tirer le fil du destin

## Take it Esy

Nous allons créer un projet nommé `sorte` (il s'agit du nom de la magie divinatoire pratiquée par les Strega de Vodacce).

Nous allons utiliser [esy.sh](https://esy.sh/), pour l'installer avec npm `npm i -g esy`.

Esy est une toolchain pour ReasonML et OCaml, inspirée du workflow de npm, et basée sur [Opam](http://opam.ocaml.org) et [Dune](https://dune.build/) dont nous parlerons ensuite.

**Esy** présente plusieurs intérêt :

- Un CLI unique pour plusieurs outils
- Le sandboxing des dépendances au niveau du projet
- Le fait de pouvoir coupler des dépenses issues de OPAM, NPM, GIT, REASON-NATIVE
- La simplification de la configuration Dune

## Initialisation

Dans notre répertoire projet, nous commençons par créer les fichiers nécessaire :

```sh
    echo '(lang dune 1.11)\n (name sorte)' >> dune-project
    echo '(dirs (:standard \ node_modules \ _esy))' >> dune
    touch package.json
    touch sorte.opam
```

- Le fichier [dune-project](https://dune.readthedocs.io/en/latest/dune-files.html#dune-project) se place à la racine du projet et sert à définir les informations communes, à minima la version de **Dune** utilisée.

> Au moment où j'écris ce billet, j'utilise la version 1.11, bien que la dernière version soit la 2.4 en raison de limite de esy avec la version 2

- Le fichier [dune](https://dune.readthedocs.io/en/latest/dune-files.html#dune) se place à la racine et dans chaque répertoire qui correspond à une unité de compilation, c'est à dire une librairie ou un exécutable.
- Le fichier [package.json](https://esy.sh/docs/en/concepts.html#manifest) est le manifeste du projet **esy**.
- Le fichier `sorte.opam` défini une librairie **opam**.

## Gestion des dépendances

Commençons par éditer une première version du manifeste `package.json` :

```json
{
  "name": "sorte",
  "version": "0.0.1",
  "description": "Sorte is a 7th characters builder written in ReasonML",
  "license": "MPL-2.0",
  "scripts": {
    "pesy": "bash -c 'env PESY_MODE=update pesy'",
    "start": "esy x SorteApp.exe",
    "test": "esy x TestSorte.exe"
  },
  "dependencies": {
    "@opam/dune": ">=1.11",
    "@esy-ocaml/reason": "*",
    "ocaml": "~4.8.1000"
  },
  "devDependencies": {
    "ocaml": "~4.8.1000",
    "refmterr": "*",
    "pesy": "*",
    "@opam/merlin": "*",
    "@reason-native/rely": "*"
  },
  "esy": {
    "build": "dune build -p <PACKAGE_NAME>",
    "buildDev": "pesy",
    "release": {
      "releasedBinaries": ["SorteApp.exe"]
    }
  },
  "buildDirs": {
    "lib": {
      "namespace": "Lib",
      "name": "sorte.lib",
      "require": []
    },
    "bin": {
      "main": "SorteApp",
      "name": "SorteApp.exe",
      "require": ["sorte.lib"]
    },
    "test": {
      "namespace": "Test",
      "name": "sorte.test",
      "ocamloptFlags": ["-linkall", "-g"],
      "require": ["sorte.lib", "rely.lib"]
    },
    "test-runner": {
      "main": "TestSorte",
      "name": "TestSorte.exe",
      "require": ["sorte.test"]
    }
  }
}
```

Comme vous le constatez, ce fichier mime le [package.json de npmjs](https://docs.npmjs.com/files/package.json) avec quelques [spécificités propres à esy](https://esy.sh/docs/en/configuration.html).

### Scripts

Les `scripts` fonctionnent comme pour npm, à la différence qu'ils se lancent avec la commande `esy [NOM_DU_SCRIPT]`.

Pour installer les dépendances, il suffit d'exécuter la commande `esy install`. C'est là que Esy commmence à montrer son intérêt : à la différence de NPM, les dépendances sont installées dans votre `$HOME/.esy` et linkées dans le répertoire `node_modules` de votre projet. C'est à dire que, d'une part, elles sont sandboxées pour votre projet, et d'autre part, qu'elles ne sont installées qu'une seule fois pour tous les projets utilisant la même version de la dépendance : **une sacrée optimisation pour votre disque dur**.

### Dependencies

Vous constatez que certaines dépendances sont préfixées par un namespace :

- `@opam/` : signifie que la librairie sur cherchée sur opam, par exemple [@opam/dune](http://opam.ocaml.org/packages/dune/)
- `@reason-native/` : signifie que la librairie sur cherchée dans le projet [reason-native.com](https://reason-native.com/) , par exemple [@reason-native/rely](https://github.com/facebookexperimental/reason-native/tree/master/src/rely)

Il est également possible d'avoir des résolutions sur npm, préfixées par `@npm/`, utiles pour les projet [js_of_ocaml](https://ocsigen.org/js_of_ocaml/3.5.1/manual/overview) ou depuis n'importe quelle origine en utilisant des [resolutions](https://esy.sh/docs/en/linking-workflow.html)

Vous pouvez mainteant exécuter le commande :

```sh
    esy install
```

### Ajouter des dépendances

Il est bien sûr possible d'ajouter les dépendences directement en utilisant le CLI.
Dans le cas de ce projet je souhaite utliser [Irmin](https://irmin.io) dont je parlerai prochainement.

```sh
esy add @opam/irmin @opam/irmin-unix @opam/irmin-git
```

## Pesy

Devoir gérer un fichier Dune dans chaque répertoire est assez rébarbatif et rend difficile une vue d'ensemble sur des projets complexes. De plus, si vous n'êtes pas issu.e de l'écosystème **OCaml**, l'utilisation de [S-Expressions](https://en.wikipedia.org/wiki/S-expression) vous est peut-être étrangère.

Pour faciliter cela, [pesy](https://github.com/esy/pesy) est très pratique. Cet sous-projet de **esy** vous permet de générer les répertoires de vos projets ainsi que les fichiers Dune, grâce à la définition d'un noeud `buildDirs` dans votre manifeste.

### Génération de configuration

Je vous propose une arborescence assez classique :

```sh
        |- bin #contient l'executable principal de notre projet
        |- lib #contient le métier de notre projet
        |- test #contient les tests de notre lib
        |_ test-runner #contient l'execution de nos tests
```

Vous pouvez mainteant exécuter le commande suivante, qui correspond au script de votre manifeste :

```sh
    esy pesy
```

N'hésitez pas à consulter les fichiers Dune générer dans chaque répertoire, pour appréhender cet outtil.

> Si vous êtes déjà familier de Dune, vous remarquerez que l'attribut **name** correspond à l'attribut **public_name** de Dune alors que l'attribut **namespace** correspond à l'attribut **name** de Dune

Vous pouvez ensuite compiler et executer le programme issu de cette génération.

```sh
    esy build # compile le projet
    esy x SorteApp.exe # exécute l'exécutable
```

ou le script que nous avons déclaré dans notre manifeste

```sh
    esy start
```

Vous venez de réalisez votre premier `Hello world` en initialisant votre projet.

Bien que beaucoup de [configurations soient disponibles](https://github.com/esy/pesy/blob/master/site/docs/supported-config.md) via **pesy**, vous pouvez rencontrer des limitations. Dans ce cas, il vous suffit de supprimer le noeud `buildDirs` de votre manifeste et de continuer à gérer manuellement vos fichiers Dune.

> A partir de la version 0.5, actuellement en alpha, pesy permet également de démarrer un projet à partir d'un template, vous pouvez utiliser le mien : `pesy --template=github:oteku/reason-native-template`

![Sterga sorte](../img/sorte.jpg)

# Changer le chemin

L'outillage esy / pesy facilite grandement le démarrage d'un projet et apporte de nouveaux avantages, vu précedemment. Plus votre projet se complexifie, plus vous aurez besoin de néanmoins connaitre les outils sous-jacents que sont **Opam** et **Dune**

## Opam

Il s'agit du gestionnaire de dépendances et du repository principal de package pour OCaml / ReasonML. Si vous souhaitez publier vos package ReasonML natifs, vous devrez vous y plonger. Rassurez vous, l'outillage est assez simple à prendre en main et [opam-publish](http://opam.ocaml.org/doc/Packaging.html#Publishing) vous facilite le travail

## Dune

Dune est une chaine de compilation pour OCaml, ReasonML et Coq. Nous avons vu une configuration relativement simple à comprendre et assez commune, néanmoins les possibilités offerte par Dune sont nombreuses (profil de tests, génération de documentation, cross-compilation, ...).

Un apport notable, si vous y avez prété attention dans notre exemple, est l'ajout de la notion de package. Nous avions vu avec les [modules ReasonML](../esy-reasonml) leur côté pervasif et le fait qu'il n'était pas possible de regrouper plusieurs modules contenus dans des fichiers différents sous un même namespace. Dune introduit la notion de package au moment de la compilation qui permet d'aggrégé plusieurs fichiers sous un même package, qui est un module d'aggrégat au vu du code qui l'utilise, cela vient enrichir les possibilités offertes en terme d'espace de nommage au sein d'une même base de code.
