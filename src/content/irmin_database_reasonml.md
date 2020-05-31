+++
title = "Découverte de la base de données Irmin" 
date = 2020-05-31
draft = false
[taxonomies]
tags = ["ReasonML"]
+++

Irmin est une base de données clé / valeur, créée pour pouvoir être distribuée facilement et qui suit les principes de Git et codée en OCaml. Une promesse suffisament intéressante pour y consacrer un billet.

<!-- more -->

> Bien que pouvant être lu indépendemment, ce billet est le quatrième de la série d'articles [ReasonML : la série](../reasonml-serie/#un-programme-reason-able)

# Yet another Key Value datastore ?

Il y a eu beaucoup de _hype_ ces dernières années sur les bases de données clé / valeur, avec des produits comme **Redis**, Google **LevelDB**, Facebook **rocksDB**, Basho **riak-kv** ou encore Amazon **DynamoDB**. Alors est-ce que Irmin apporte quelque chose de nouveau ?

## Qu'est-ce qu'une base clé / valeur ?

Une base de donnée clé / valeur est une base NoSQL qui stocke les données sous forme de paire clé-valeur, où la sert d'identifiant unique. On parle parfois également de _dictionnaire_ ou de _table de hash_.

![kv](../img/keys.png)

Ce type de datastore sont intéressant car ils sont fortement clusterisables, ce qui offre des capacités de scalabilité horizontale intéressante, mais également la capacité de pouvoir servir de base de données dans des applications réparties en pair à pair.

## Les principaux usages

### Cache serialisé

Il s'agit surement de l'usage principal, sérialiser des valeurs indexées par une clé afin de partager une information entre plusieurs instances d'une même application.

Par exemple, tracer la dernière tentative de login d'une IP pour détecter des attaques Brute force :

      | Key            | Value                       |
      | ---------------|---------------------------: |
      | 149.178.232.77 |   2020-03-18T11:12:55+0000  |
      | 120.32.234.80  |   2020-03-10T19:08:37+0000  |

### Directory

Les clés peuvent être organisées de manière arborescente afin de modéliser un annuaire ou un catalogue.

Par exemple un catalogue de référeces d'outils :

      | Key            | Value                       |
      | ---------------|---------------------------: |
      | clé/60044201   |   Clé à molette 380 mm      |
      | clé/81989876   |   Clé à pipe 19 mmm         |
      | clé/65997463   |   Clé à griffe 17 mm        |

### Base document

Les bases orientées documents sont en réalité une spécialisation des bases clé/valeur, donc la valeur peut être un document, en général représenté au format JSON.

Par exemple, un suivi d'une flotte de véhicules :

      | Key            | Value                          |
      | ---------------|------------------------------: |
      | 5Y2SR67049Z45  |   {"color" : "Black",          |
      |                |        "license" : "MYCAR00",  |
      |                |        "year" : "2012",        |
      |                |        "make_and_model" :      |
      |                |         ["Honda", "Civic"],    |
      |                |        "owner" : "Mike Jones"} |
      | ---------------|------------------------------: |
      | 7B1QK0987X976  |   {"color" : "Kaki",           |
      |                |        "license" : "ABCDSZ",   |
      |                |        "year" : "2007",        |
      |                |        "make_and_model" :      |
      |                |         ["Renault", "Twingo"], |
      |                |        "owner" :"Danny Boon"}  |
      | ---------------|------------------------------: |

### Middelware de PUB/SUB

Publish-Subscribe est un pattern de messagerie où les éditeurs de messages catégorisent les messages publiés sans connaitre les abonnés qui les consommeront. Il est courant d'utiliser une base KV pour gérer le pipeline de messages. Cela demande en général du code complémentaire pour créer un middleware de PUB/SUB, cependant certaines bases comme _Redis_ intègrent nativement genre de mécanisme.

Par exemple, créer un système de messagerie :

      | Key            | Value                                 |
      | ---------------|-------------------------------------: |
      | topic/A/B/C    | { "user" : "John", "msg" : "coucou" } |
      | topic/A/B/C    | { "user" : "Jack", "msg" : "Yo!!" }   |
      | topic/A/B/D    | { "user" : "Jaine", "msg" : "Ohiho" } |

## Qu'est-ce qu'Irmin

Irmin est une base de données clé / valeur, qui permet donc de mettre en oeuvre les différents pattern vus précédemment, créé par l'équipe [Mirage](https://mirage.io). La promesse de cette solution est de proposer une entrepôt de données facilement distribuable, grâce aux principes de Git : branches et merges.

Un plus de cela, Irmin propose nativement :

- Un serveur HTTP / REST et un serveur GraphQL pour exposer une API
- Un système de snapshot pour les sauvegarde et restauration de données
- Plusieurs backends (en mémoire, git, système de fichiers, fichiers partitionnés, fichiers compressés, unikernel mirageOS)
- La possibilité de créer son propre backend (redis, postgres, ...), il suffit de la coder en respectant les contrats de types fournis
- Une solution portable sur système posix (Linux, macOS, Windows WSL, ...), dans un navigateur (grâce à [js_of_ocaml](https://github.com/ocsigen/js_of_ocaml)) ou sur un unikernel MirageOS.

### Utilisation Standalone

Commençons par une utilisation _standalone_ d'Irmin. En pré-requis, vous devez disposer d'un installation de [opam](http://opam.ocaml.org/doc/Install.html) et [OCaml](https://ocaml.org/docs/install.fr.html) en version supérieur à la `4.05.0`

Vérifiez votre version de OCaml :

```shell
$ ocaml --version
The OCaml toplevel, version >=4.05.0
```

Installez `irmin-unix` avec `opam`

```shell
$ opam install irmin-unix
```

Créez votre première base Irmin :

```shell
$ mkdir -p /tmp/irmin/example && cd /tmp/irmin/example
$ irmin init
```

Nous pouvons maintenant utiliser notre base avec le CLI :

```shell
$ irmin set -s git "149.178.232.77" 2020-03-18T11:12:55+0000
$ irmin get -s git "149.178.232.77"
2020-03-18T11:12:55+0000
$ irmin set -s git cle/60044201 "Clé à molette 380 mm"
$ irmin list -s git /
FILE 149.178.232.77
DIR cle
$ irmin tree -s git
/cle/60044201.........................................Clé à molette 380 mm
/149.178.232.77.....................................2020-03-18T11:12:55+0000

```

Les commandes se lisent :

- `irmin set` permet d'écrire une valeur, l'argument `-s` permet de spécifier le backend (ici git), le premier paramètre représente la clé et le second la valeur ; comme on le voit une clé peut être une chaine de caractère ou un path.
- `irmin get` permet de lire une valeur, le premier paramètre représente la clé dont on veut récupérer la valeur
- `irmin tree` permet de lire les données d'un store et `irmin list $PATH` liste le contenu d'un path spécifique

### Serveur Graphql intégré

La librairie `irmin-unix` dispose également d'un serveur GraphQL prêt à l'emploi :

```shell
$ irmin graphql --port 5000
```

Nous pouvons maintenant utiliser un client graphQL (ou n'importe quel client capable d'exécuter une requête POST) pour consilter nos données, par exemple avec `curl` nous pouvons lire la valeur stockée précédemment :

```shell
$ curl -X POST -d '{"query": "{master{tree{get(key:\"149.178.232.77\")}}}"}' \
-H "Content-Type: application/json" http://localhost:5000/graphql

{"data":{"master":{"tree":{"get":"2020-03-18T11:12:55+0000"}}}}
```

Le serveur est configuré avec un clients [GraphiQL](https://github.com/graphql/graphiql) exposé à cette adresse : [http://localhost:5000/graphql\_](http://localhost:5000/graphql_) qui permet d'exploré le schéma et les données.

Irmin fournit en complément des clients en js et go :

- Js GraphQL client https://github.com/zshipko/irmin-js
- Go GraphQL client https://github.com/zshipko/irmin-go

> Il est également possible de démarrer une api HTTP REST, pour cela il suffit d'exécuter `irmin init --daemon`. Cependant cette API est assez bas niveau et non documenté, il est recommander d'utiliser l'API Graphql ou bien de coder votre propre API haut niveau si nécessaire

### Sauvegarde et restauration de base

Il est également possible de faire une sauvegarde de sa base :

```shell
$ irmin snapshot
a549f1538a15e9865677189d84c607b4d4777646
```

puis de la restaurer à partir du SHA1 :

```shell
$ irmin revert a549f1538a15e9865677189d84c607b4d4777646
```

### Distribuer son data store

Irmin permet de synchroniser plusieurs stores entre eux pour obtenir une base distribuée. A ce niveau, rien de magique, Irmin tiens sa promesse d'utilisation de Git, lui même un système distribué.

Pour répliquer son store il suffit de `push` :

```shell
$ irmin push $MY_GIT_RMOTE_REPOSITORY
```

pour initialiser depuis un autre repository :

```shell
$ irmin clone $MY_GIT_RMOTE_REPOSITORY
```

ou pour synchroniser

```shell
$ irmin pull -s $MY_GIT_RMOTE_REPOSITORY
```

### Une autre base KV ... avec un backend git & un serveur GraphQL

A ce stade, nous avons donc "simplement" une base clé / valeur traditionnelle, intégrant les principes de Git et un serveur GraphQL : c'est déjà très intéressant ! En quelques lignes de commandes, nous avons notre base local et la possibilité de la synchroniser avec n'importe quel serveur Git, y compris Gitlab ou Github.

Mais nous avons également quelques faiblesses :

- Le serveur GraphQL présente un schéma très "technique", en gros il propose une exploration d'un serveur Git, dans une logique conception dirigée par les domaines, [DDD](https://fsharpforfunandprofit.com/books/), on préfèrerait exposer des **domaines**
- Le système de type de cette base est extrêmement pauvre, puisqu'il propose 3 types : `string`, `json` ou `json_value`

# Utilisation avec ReasonML (ou OCaml)

Là où `irmin-unix` est un CLI, Irmin est également distribué sous forme d'une collection de librairies OCaml.

## Le domaine

Revenons à l'exemple des précédents articles où nous avons commencer à travailler autour d'un créateur de personnages pour le jeu de rôle 7ème Mer ; pour notre exemple nous disposerons d'une version simplifié du domaine **Hero**

```reason

    module Nation = {
        type t =
            | Castille
            | Montaigne
            | Vodacce;
    };

    module Trait = {
        type t = {
            brawn: int,
            finesse: int,
            resolve: int,
            wits: int,
            panache: int,
        };
    };

    module Hero = {
        type t = {
            id: string,
            name: string,
            nation: Nation.t,
            trait: Trait.t,
        };
    };
```

Cela nous permet par exemple de créer ces deux célèbres héros avec ces valeurs :

```reason

    let inigo_montoya =
    Hero.{
        id: "567de924-cc04-41a0-acc8-431dd332ce79",
        name: "Inigo Montoya",
        nation: Castille,
        trait: {
        brawn: 2,
        finesse: 5,
        resolve: 3,
        wits: 2,
        panache: 4,
        },
    };
    let vizzini =
    Hero.{
        id: "9779a6fa-a7fe-4475-a546-350b5e3c3b56",
        name: "Vizzini",
        nation: Vodacce,
        trait: {
        brawn: 2,
        finesse: 2,
        resolve: 4,
        wits: 4,
        panache: 3,
        },
    };
```

## Jouons avec Irmin

Pour réaliser le programme à suivre, nous avons besoin des dépendances : `irmin`, `irmin-unix`, `irmin-git`, `lwt` et `lwt_ssl`. Si vous ne savez pas comment faire, lisez le billet sur l'[outillage projet](../esy-reasonml/#gestion-des-dependances)

### Des données "type safe"

Un des intérêts d'utiliser un système de typage statique est d'apporter plus de sécurité dans les valeurs manipulées, c'est bien ce qu'on va chercher pour les valeurs que nous voulons stocker grâce à Irmin. On ne peut pas directement utiliser nos types, mais on nous n'avons pas non plus à gérer un mapping entre deux systèmes de types distincts, comme on le fait habituellement avec un ORM. En effet, puisqu'on partage le même langage, Irmin permet d'utiliser n'importe quelle valeur de type `Irmin.Type.t('a)` pour définir les valeurs d'un store. Nous allons donc simplement créer des types compatibles, encapsulé dans un module : cette opération est relativement simple car Irmin fournit des fonctions pour représenter les **variants** et les **record**

```reason
module IrminHero = {
  type t = Hero.t;
  let nation =
    Irmin.Type.(
      Nation.(
        variant("nation", (castille, montaigne, vodacce) =>
          fun
          | Castille => castille
          | Montaigne => montaigne
          | Vodacce => vodacce
        )
        |~ case0("Castille", Castille)
        |~ case0("Montaigne", Montaigne)
        |~ case0("Vodacce", Vodacce)
        |> sealv
      )
    );
  let trait =
    Irmin.Type.(
      Trait.(
        record("trait", (brawn, finesse, resolve, wits, panache) =>
          {brawn, finesse, resolve, wits, panache}
        )
        |+ field("brawn", int, t => t.brawn)
        |+ field("finesse", int, t => t.finesse)
        |+ field("resolve", int, t => t.resolve)
        |+ field("wits", int, t => t.wits)
        |+ field("panache", int, t => t.panache)
        |> sealr
      )
    );
  let t =
    Irmin.Type.(
      Hero.(
        record("hero", (id, name, nation, trait) =>
          {id, name, nation, trait}
        )
        |+ field("id", string, t => t.id)
        |+ field("name", string, t => t.name)
        |+ field("nation", nation, t => t.nation)
        |+ field("trait", trait, t => t.trait)
        |> sealr
      )
    );
  let merge = Irmin.Merge.(option(idempotent(t)));
};
```

J'ai mis ici le code pour vous montrer qu'il n'y a rien de magique, mais il est possible d'utiliser un ppx pour réduire le code _boilerplate_ : [https://github.com/mirage/irmin/blob/master/README_PPX.md](https://github.com/mirage/irmin/blob/master/README_PPX.md)

Maintenant que nous avons nos types, il nous reste à définir un data store et les opérations sur ce store. Encore une fois, cela est très facile grâce aux [Foncteurs](../reasonml-modules/#les-foncteurs) mis à disposition par Irmin :

```reason
module HeroStore = Irmin_unix.Git.FS.KV(IrminHero);
module Sync = Irmin.Sync(HeroStore);
```

### Prépartion du repository

Il nous faut ensuite définir notre repository de données :

```reason
let gitConfig = Irmin_git.config(~bare=true, "/path/to/my/local");
let gitRepo = HeroStore.Repo.v(git_config);
let gitRemote =
  HeroStore.remote(
    "https://login:password@path/to/my/remote.git",
  );
```

Ce qui peut nous permettre dans un premier temps de définir ces quelques fonctions utilitaires :

```reason
/* Access master brach */
let master = config => HeroStore.Repo.v(config) >>= HeroStore.master;
/* Access a named brach */
let branch = (config, name) =>
  HeroStore.Repo.v(config) >>= (repo => HeroStore.of_branch(repo, name));
/* Add info to "commit" */
let info = (author, message) => Irmin_unix.info(~author, "%s", message);
```

### Exemple de programme

```reason
open Lwt.Infix;

let main =
  Lwt.join([
    HeroStore.Repo.v(git_config)
    >>= HeroStore.master
    >>= (
      t =>
        HeroStore.set_exn(
          t,
          [inigo_montoya.id],
          inigo_montoya,
          ~info=info("oteku", "create Montoya"),
        )
        >>= (
          () =>
            HeroStore.get(t, [inigo_montoya.id])
            >|= (s => assert(s == inigo_montoya))
        )
    ),
    HeroStore.Repo.v(git_config)
    >>= HeroStore.master
    >>= (
      t =>
        HeroStore.set_exn(
          t,
          [vizzini.id],
          vizzini,
          ~info=info("oteku", "create Vizzini"),
        )
        >>= (
          () =>
            HeroStore.get(t, [vizzini.id]) >|= (s => assert(s == vizzini))
        )
    ),
  ])
  >>= (
    () =>
      HeroStore.Repo.v(git_config)
      >>= HeroStore.master
      >>= (t => Sync.push(t, git_remote))
  )
  >>= (_ => print_endline("finished") |> Lwt.return);

let () = Lwt_main.run(main);

```

Et voilà ! J'ai présenté Irmin lors du Lambda Remote 2 dont voici la vidéo :

<iframe width="560" height="315" src="https://www.youtube.com/embed/BT2e-DkcVQo" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
