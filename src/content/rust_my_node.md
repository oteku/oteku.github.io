+++
title = "Rust my Node.js" 
date = 2019-06-20
[taxonomies]
tags = ["rust"]
+++

Si vous êtes développeur node.js vous vous confronterez tôt ou tard au développement d'addons natifs ... et à tout un lot de nouveaux problèmes : langage C++ en lui même, mais également API V8, build system ou dépendance aux versions de V8. Pourtant dès que vous avez besoins de multi-threading, d'accès aux ressources machine ou même simplement pour réutiliser des librairies existantes vous n'y coupez pas. Ce billet vise à vous faire découvrir comment le langage Rust permet de rendre vos modules natifs "fast & safe".

## Une histoire de Node

J'aime beaucoup le runtime [Node.js](https://nodejs.org) :

- Un écosystème impressionnant grâce à [npm](https://www.npmjs.com/), qui se trouve être un excellet outil de gestion de dépendance, de sandboxing de projet et de publication de librairie
- La communauté javascript est très prolifique, ce qui permet également de trouver beaucoup de librairies intéressante via npm
- Le runtime est très performant pour créer des API web et de manière générale, pour tout cas d'usage consommateur d'I/O
- Le modèle de gestion de l'asynchronisme proposé par l'event-loop, mimant la webAPI JS, est également une force

Tout ceci est supporté par une architecture robuste, rendue possible principalement grâce au moteur ECMAScript [V8](https://v8.dev/) et la librairie [libuv](http://libuv.org/).

![Node.js architecture](../img/node.png)

Node.js est donc un runtime C/C++ qui exécute du code Javascript. Cependant Javascript est un langage conçu initialement pour être exécuté dans un navigateur web. Pour des raisons de sécurité un certain nombre d'actions ne sont pas possible depuis un navigateur et de fait ne font pas parti des spécifications et API javascript, par exemple l'accès direct au système de fichier, accès aux périhériques réseaux, ...

Node.js fournit donc une [API](https://nodejs.org/dist/latest-v12.x/docs/api/) permettant d'accéder à certaines des ces fonctionnalités pour réaliser de réelles applications serveur en Javascipt. En réalité, ces modules sont des programmes C++ qui expose des bindings javascript grâce à l'API de V8. Ceci est "masqué" par node.js quand vous utilisez des modules tel que `fs` ou `net`. Cepedant cette API ne pouvant être exhaustive et pour ouvrir le champ des possibles, Node.js permet également de faire des addons C++ et d'exposer vos propres bindings.

Lorsque l'on développe une application pour Node.js nous pouvons donc faire du code Javascript ou du code C++ packagé sous forme d'addon.

## Que sont ces addons ?

- Des « dynamically-linked shared objects », écrits en C++, en utilisant l’api V8 api, qui peuvent être importé par la fonction `require()`
- Des modules compilés dépendant de V8 et donc dépendant de la version de node et de l'architecture du processeur

Depuis Node 8, il existe [n-api](https://nodejs.org/dist/latest-v12.x/docs/api/n-api.html), une abstraction indépendante de la version de V8.

Un addon doit donc être compilé pour chaque version de node et chaque architecture. En général, il suffit de prévoir le build de l'addon dans le script npm `postinstall` de son projet.

## A quoi ça sert ?

- Réutiliser du code C ou C++ existant dans votre base de code d'entreprise
- Utiliser des librairies binaires : statiques (.a) ou dynamiques (.so / .dylib / .dll), potentiellement des librairies tierces non libres.
- Viser des performances natives, ce qui peut être intéressant pour certains algoritmes
- Avoir accès aux ressources systèmes, non accessibles depuis Javascript (I/O, ports séries, GPU, …)
- Utiliser des worker threads pour des algo plus intéressant en multithreading (Il est possible depuis Node 10.5 de faire du multithreading en javascript mais cela reste expérimental et limité)
- Typer statiquement une librairie

## Les anti-patterns

A ce stade on pourrait être tenter de réaliser toute son application sous forme d'addon ! Ce n'est pas le but et il y a quelques anti-patterns à connaitre :

- Vouloir ré-écrire l'event-loop : node a été conçu pour ça, libuv est "battle tested"
- Faire des I/O intensif : là encore c'est la foce de libuv
- Uniquement typer un programme : si le côté dynamique de javascript vous dérange, d'autres approches sont plus productives :
  - Js as a Bytecode : avoir un langage statique qui compile vers Javascript, tel que OCaml + js_of_ocaml, F# + Fable, ou Purescript. Ces compilateurs apportent beaucoup d'optimisations et ces langages sont plus sûrs que C++
  - Webassembly : quand vous êtes dans un langage ne disposant pas d'un bon compilateur vers JS mais disposant d'un compilateur wasm (ex : Rust). C'est d'ailleurs l'objectif de WASM de servir d'assembleur pour le web et d'éviter le passage par JS. De plus Node.js peut tout à fait charger un module WASM.

**Donc je peux utiliser Javascript et C++ en même temps**
![Large amount of code](../img/large.png)

C++ est un langage qui cumule beaucoup de problématiques : unsound, unsafe, manque d'outillage, ...
Néanmoins c'est un langage parfois utile pour faire des programmes _bas niveau_ performant.

A titre personnel, j'utilise [Rust](https://www.rust-lang.org/) pour ce type de besoin. Les avantages de Rust de manière synthétique sont :

- Un langage _Memory Safe_
- Un compilateur qui bloque la plupart des erreurs de runtime
- Un interfaçage facile avec C/C++
- La programmation générique
- Un système de _type ML_, incluant types algébriques et filtrage par motif
- Pas de _rammasse miette_
- Pas d'allocation / désallocation manuelle de mémoire
- Pas de _segmentation fault_
- Pas de _data race_
- Un outillage impressionant
- Compile vers des applications natives, des librairie rust ou C, du webassembly ou même des addon node.js

Effectivement le projet [Neon Bindings](https://neon-bindings.com/) permet de compiler une librairie rust vers un addon natif node, et de l'utiliser directement depuis votre code javascript.

Vous pouvez découvrir **Neon** avec ces quelques exemples : https://github.com/oteku/rust-my-node

- fibo-sync : comparer les performances d'un calcul _couteux_ (ici un fibonacci naïf) en Javascript et Rust.
  - Sur des _petits calculs_ (`node fibo-sync.js --value 1`), javascript est plus performant : c'est assez logique nous sommes dans le cas où le _coût_ d'appel d'un addon est supérieur au coût du calcul
  - Sur de _gros calculs_ (`node fibo-sync.js --value 45`), on a un gain notable
  - Il est aisé grace au type `JsResult` de Neon de passer des erreurs du code Rust au code Javascript (`node fibo-sync.js --value 50`)
- fibo-async : dans un programme node.js, on prend l'habitude découper un algorithme couteux en code asynchrone pour ne pas bloquer l'event loop. Neon offre un trait `Task` qui permet facilité la création de code asynchrone dans vos addons et de ne pas bloquer la callstack JS (`node fibo-async.js --value 45`)
- foldersize : sert à montrer comment un addon permet de bénéficier de librairies Rust existantes pour les réutiliser au sein d'un programme node (`node foldersize.js`)

_Ce billet a été rédigé pour servir de pilote au talk Rust my node présenté lors de [Lambda Lille#14](https://www.meetup.com/fr-FR/LambdaLille/events/260541114/) et d'un [BBL Zenika](https://www.meetup.com/fr-FR/NightClazz-Lille-by-Zenika/events/262219651)_
