+++
title = "ReasonML : la série" 
date = 2019-12-11
draft = false
[taxonomies]
tags = ["ReasonML"]
+++

Je me lance dans l'exercice de la série d'article. Pour commencer, je souhaite partager avec vous un langage et un ecosytème qui me passionne depuis 3 ans **ReasonML**

Si vous ne connaissez pas encore ce langage, il s'agit d'une syntaxe de **OCaml** développée au sein de Facebook par [Jordan Walke](https://twitter.com/jordwalke), le _papa_ de ReactJS. Facebook n'en est pas à ses début avec l'écosystème OCaml puisque ce dernier a notament servi à réaliser le prototype de react avant de passer sur Javascript pour des raisons _marketing_, à réaliser la machine virtuelle PHP/Hack [HHVM](https://github.com/facebook/hhvm/tree/master/hphp/hack) ou encore à réaliser le typechecker javascript [Flow](https://github.com/facebook/flow)

<!-- more -->

# A Reason why

L'intention derrière le projet [ReasonML](https://reasonml.github.io/) tiens dans cette promesse

> Reason lets you write simple, fast and quality type safe code while leveraging both the JavaScript & OCaml ecosystems.

Dis autrement, partant du postulat que la syntaxe est un problème à l'accès au merveilleux écosystème OCaml, **ReasonML** propose d'introduire une syntaxe le plus proche possible de celle de Javascript au dessus du modèle de type d'OCaml. Dès le départ, il y a clairement une intention de faciliter le _Javascript as a bytecode_, nous aurons l'occasion d'en reparler, mais pas que. A l'inverse, des langages tels que le populaire Typescript ou le plus confidentiel Purescript, en passant par Clojurescript ou Elm, la volonté n'est pas de créer un nouveau langage dédié à la compilation vers js, mais un langage complet dont la compilation vers js n'est qu'une des possibilité. Dès lors, s'appuyer sur un ecosystème riche de plus de 20 ans d'expérience est un gage de confiance.

# Tour d'O-Reason

Avant de poursuivre, je souhaite donner quelques éléments de syntaxe :

## Déclaration de valeurs (let bindings)

Si vous avez déjà utilisé Flow, vous ne devriez pas être surpris. Sinon le mot clé `let` sert à lié une valeur à un nom, ici `greeting`, suivi de la déclaration de type, `: string` puis de la valeur `= "hello"`.

```reason
    /* Ceci est un commentaire */
    let greeting : string = "hello";
```

Les valeurs sont immutables par défaut en ReasonML. C'est plutôt une excellente nouvelle, néanmoins il est possible de simuler des variables en utilisant des références ; dans la plupart des situations, vous ne devriez pas en avoir besoin.

```reason
    let score : int = 10;
    let scoreMutable : ref(int) = ref(0);
    scoreMutable := 5;
```

Il est possible de définir des alias de type afin de rendre le code plus lisible, ce qui est toujours appréciable dans une démarche [DDD](http://blog.infosaurus.fr/public/docs/DDDViteFait.pdf).

```reason
    type scoreType = int; /* type alias */
    let myScore : scoreType = 7;
```

Les fonctions sont des valeurs comme les autres et peuvent être exprimées dans le système de types

```reason
    let concatStr : (string, string) => string = (a, b) => a ++ b ;
    /* ++ est l'opérateur de concaténation de 2 string */
```

## Inférence de type

ReasonML est capable d'inférer le type de vos expressions, ce qui permet d'écrire du code très proche de ce que vous feriez en Javascript.

```reason
    let twelve = 12; /* val twelve : int */
    let addInt = (a, b) => a + b; /* val addInt : (int, int) => int */
    let addFloat = (a, b) => a +. b; /* val addInt : (float, float) => float */
    let aListOfInt = [1, 2, 5]; /* val aListOfInt : list(int) */
```

Les types peuvent recevoir des paramètres, à l'image de génériques dans d'autres langages. Les paramètres de types commencent toujours par `'`.

```reason
    type coordinate('a) = ('a, 'a, 'a);
    type intCoordinate = coordinate(int);
    let int3DPoint: intCoordinate = (1, 2, 10);
    type floatCoordinate = coordinate(float);
    let float3DPoint: floatCoordinate = (1., 2., 10.);

    type transfert('a, 'b) = coordinate('a) => coordinate('b);
    type intToFloatTransfert = transfert(int, float);
    let intToFloatCoodinate: intToFloatTransfert = ((x, y, z)) => (float_of_int(x), float_of_int(y), float_of_int(z));
```

## Opérateur de chaînage

ReasonML fournit un opérateur de chaînage (pipe operator) `|>` qui fonctionne à l'image du pipe `|` unix, c'est à dire que la valeur à gauche est fournit comme paramètre à droite de l'expression à droite de l'opérteur :

```reason
    let compose = (f, g, x) => g(f(x));
    /* === */
    let compose2 = (f, g, x) => f(x) |> g;

    let foo = (f,g) => compose(f,g, 5);
    /* === */
    let bar = (f,g) => 5 |> compose(f,g);
```

## Application partielle

Les fonctions ReasonML sont curryfié c'est à dire que la fonction de type `('a,'b) => 'c` est juste du sucre syntaxique pour la fontion de type `'a => 'b => 'c`

```reason
    let add = (x, y) => x + y; /* === let add = x => y => x + y */
    let add5 = add(5); /* === let add5 = y => add(5,y) */

    let sub = (x, y) => x - y; /* === let sub = x => y => x - y */
    let sub2 = 2 |> sub; /* === let sub2 = x => sub(x, 2) */
```

# React to the future

Les motivations qui ont animé la création de ReasonML (en anglais) :

<iframe width="560" height="315" src="https://www.youtube.com/embed/5fG_lyNuEAw" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

# Un programme Reason-able

Dans cette série de découverte, nous aborderons ensemble prochainement :

- [Types de données algébriques](../reasonml-adt)
- [Les modules ReasonML](../reasonml-modules)
- [Outillage d'un projet ReasonML](../esy-reasonml)
- Tests de propriétés
- Compilation vers Javascript
- GUI avec Revery

Pour illustrer le propos, nous allons développer un générateur de personnage pour le jeu de rôle [Les secrets de la 7eme mer](http://www.legrog.org/jeux/secrets-de-la-7eme-mer) seconde édition.
![Vodacce banner](../img/theah.jpg)
