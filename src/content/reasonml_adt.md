+++
title = "ReasonML : types de données algébriques" 
date = 2019-12-12
draft = false
[taxonomies]
tags = ["ReasonML"]
+++

Les **types de données algébriques**, aussi appelés **algebraic data types** ou **ADT**, sont une classe de types de données composites, c'est à dire de nouveaux types créés dans un langage de programmation à partir de primitives de types.

On distingue principalement 4 types d'ADT issus de la théorie des catégories : les types sommes, les types produits, les types exponentiels et les type récursifs. ReasonML permet de définir de nouveaux types permettat de modéliser les ADT, nous allons voir comment et leur intérêt.

<!-- more -->

> Ce billet est le premier de la série d'articles [ReasonML : la série](../reasonml-serie/#un-programme-reason-able)

# Heros de Théah

## Les types produits

Pour représenter un point dans un référentiel à 3 dimensions, on a tendance à utiliser un truple `(x, y, z)`. Un point 3D peut donc se définir comme le _produit cartésien_ des ensembles dans lesquels il est représenté dans \\( \mathbb{R}^3 = \mathbb{R} \times \mathbb{R} \times \mathbb{R} \\) , c'est pourquoi on parle de type **produit**

En ReasonML, on peut définir ce type ainsi :

```reason
  type point3D = (float, float, float);
  let somePoint = (3.0, -6.2, 7.9);
```

Chaque personnage du monde de Théah est défini par ses compétences (traits), sa nation, ses historiques (backgrounds), ses compétences (skills), ses avantages (advantages), ses arcanes (arcanas) et ses histoires (stories). A ce stade, sans même définir le type de chacune de ses données, on peut imaginer le type `hero` comme le n-upplet de ces données.

```reason
    type hero('a, 'b, 'c, 'd, 'e, 'f, 'g) = ('a, 'b, 'c, 'd, 'e, 'f, 'g);
```

> ici le type héro est paramétré par les type 'a, 'b, 'c, 'd, 'e, 'f, 'g : il n'est pas nécessaire de comprendre cela à ce stade nous en reparlerons

On se rend bien compte qu'en augmentant le nombre de données servant à définir un type produit, le n-upplet n'est plus très parlant. C'est pourquoi on préfèrera utiliser un type enregistement ou record. Un record est un n-uplet pour lequel on fournit un label à chacune de ses données :

```reason
    type hero('a, 'b, 'c, 'd, 'e, 'f, 'g) = {
        traits : 'a,
        nation : 'b,
        backgrounds : 'c,
        skills : 'd,
        advantages : 'e,
        arcanas : 'f,
        stories: 'g
    };
```

Nous aurions également pu définir notre point 3D ainsi :

```reason
  type point3D = {
      x : float,
      y : float,
      z : float
  };
  let somePoint = {
      x : 3.0,
      y : -6.2,
      z : 7.9
  };
```

Dans 7ème mer, il existe 5 caractéristiques (traits) : la force (brawn), la finesse, la résolution (resolve), l'astuce (wits) et le panache. Un héro possède toujours les 5 caractéristiques avec une valeur associée.

```reason
  type traits = {
      brawn : int,
      finesse : int,
      resolve : int,
      wits : int,
      panache : int
  };
```

## Les types alias

Pour faciliter la lecture du code, on peut souhaiter introduire du typage sémantique. Dans notre exemple, à quoi sert le `int` passé en paramètre des constructeurs ? ReasonML offre cette possibilité à travers les type alias aussi appelés abréviations.

```reason
  type traitScore = int;

  type traits = {
      brawn : traitScore,
      finesse : traitScore,
      resolve : traitScore,
      wits : traitScore,
      panache : traitScore
  };

  let myHeroTraits : traits = {
      brawn : 2,
      finesse : 3,
      resolve : 5,
      wits : 2,
      panache : 4,
  };
```

## Les types sommes

Il est parfoit utile de pouvoir décrire un type comme pouvant prendre un nombre limité de valeurs, c'est le but des **types sommes**, parfois appelés **types énumérés** ou **variants**. On parle de _somme_ en référence à la somme logique où \\(A + B \\) signifie **A ou B** (également noté \\(A \lor B \\) ).

```reason
  type trait =
      | Brawn
      | Finesse
      | Resolve
      | Wits
      | Panache
  ;
```

Les noms `Brawn`, `Finesse`, `Resolve`, `Wits`, `Panache` sont des constructeurs du type `trait`. Les constructeurs peuvent également se voir associer une valeur.

En réutilisant les concepts précédents nous pouvons également définir les nations des règles de base, en tenant en compte que le choix d'une nation donne un bonus sur une compétence, on peut paramétrer ses constructeurs par le type `trait`.

```reason
  type nation =
      | Avalon(trait)
      | Inismore(trait)
      | TheHighlandMarches(trait)
      | Castille(trait)
      | Eisen(trait)
      | Montaigne(trait)
      | Sarmatia(trait)
      | Ussura(trait)
      | Vesten(trait)
      | Vodacce(trait)
  ;
```

Les variants peuvent également servir à restreindre les valeurs possibles au sein d'un type, c'est un moyen de s'assurer de ne représenter que des valeurs ayant un sens dans le système, et au passage de restreindre la mémoire nécessaire pour les représenter.

Dans 7ème mer, une caractéristique se voit toujours associée une valeur de 0 à 5.

Les `int` comme leur alias `traitScore` sont représenté sur 32 bits en reasonML, c'est beaucoup plus que nécessaire pour représenter les entiers de 0 à 5.

De plus, 31 bits servent à représenter l'entier. Nous avons donc \\( 2^{31} \\) valeurs possibles pour seulement 6 valeurs autorisées.

```reason
  type traitScore =
      | Zero
      | One
      | Two
      | Three
      | Four
      | Five
  ;
```

On ne peut plus à ce stade que représenté des caractéristiques de 0 à 5 : c'est à la fois explicite pour qui lit ce code mais également une sécurité suppélmentaire dans notre développement.

En réalité, pour un héro les valeurs possibles vont de 2 à 5, soit 4 valeurs autorisées, nous pouvons donc encore restreindre ce type.

```reason
  type traitScore =
      | Two
      | Three
      | Four
      | Five
  ;
```

## Les types récursifs

Un **type récursif** est simplement un type dont la définition fait appel à lui-même de manière récursive. Pour être légitime, un type récursif doit être un type somme avec au moins un constructeur de type non récursif et au moins un constructeur récursif.

Un usage courant est l'utilisation de l'[axiome de Peano](https://fr.wikipedia.org/wiki/Axiomes_de_Peano) pour représenter les entiers naturels :

```reason
  type natPeano =
      | Zero
      | Succ(natPeano)
  let nat0 = Zero;
  let nat4 = Succ(Succ(Succ(Succ(Zero))));
```

Nous pourrions utiliser un type récursif, couplé à d'autres techniques disponibles en ReasonML, pour représenter les entiers de 2 à 5, cependant c'est un peu lourd pour 4 valeurs possibles. A ce stade nous conserverons notre variant.

## Les types exponentiels

Il existe également des types exponentiels. Le type noté \\( A^{B} \\) détermine l'ensemble des transformations possibles d'un ensemble B vers un ensemble A. Ce type est en réalité le type de la fonction qui pour un paramètre dans B retourne une valeur dans A. ReasonML permet de définir des types de fonction et donc :

```reason
  type betaToAlpha('a, 'b) = 'b => 'a;
```

par exemple le type \\( int^{traitScore} \\)

```reason
  type traitScoreToInt = traitScore => int;
```

## Les types polymorphes

Cela fait deux fois que nous voyons des déclarations de types avec des paramètres `'a` et `'b` , à la manière de ce qui existe avec les génériques dans d'autres langages, ces paramètres servent à retourner un nouveau type à partir d'arguments fournis au type initial. Les paramètres de types commences toujours par `'`.
Nous aurions donc pu définir notre dernier type ainsi :

```reason
  type traitScoreToInt = betaToAlpha(int, traitScore);
```

Les types sommes ou produits peuvent également être polymorphes

```reason
  type point3D('a) = {
    x: 'a,
    y: 'a,
    z: 'a,
  };

  type option('a) =
      | None
      | Some('a);
```

# Construire un héro

A ce stade nous avons :

```reason
  type traitScore =
      | Two
      | Three
      | Four
      | Five
  ;

  type trait =
      | Brawn
      | Finesse
      | Resolve
      | Wits
      | Panache
  ;

  type traits = {
      brawn : traitScore,
      finesse : traitScore,
      resolve : traitScore,
      wits : traitScore,
      panache : traitScore
  };

  type nation =
      | Avalon(trait)
      | Inismore(trait)
      | TheHighlandMarches(trait)
      | Castille(trait)
      | Eisen(trait)
      | Montaigne(trait)
      | Sarmatia(trait)
      | Ussura(trait)
      | Vesten(trait)
      | Vodacce(trait)
  ;

  /* On limite le héro à ses compétences et nation pour le moment */
  type hero = {
      traits : traits,
      nation : nation,
  };

  let elAgilCamello = {
      traits : {
        brawn : Two,
        finesse : Four,
        resolve : Two,
        wits : Two,
        panache : Three
      },
      nation : Castille(Finesse)
  };

  let theToughCamel = {
      traits : {
        brawn : Three,
        finesse : Two,
        resolve : Four,
        wits : Two,
        panache : Two
      },
      nation : Avalon(Resolve)
  };

```

## La correspondance de motifs

Une fonctionnalité très intéressante des systèmes de types ML est leur capacité à démonter les structures de données et à effectuer du filtrage (pattern matching) sur les données directement, sans avoir à créer des getter comme on le voit dans les systèmes à base de classes.

Par exemple, si on veut récupérer les traits de elAgilCamello et la nation de theToughCamel, on peut faire :

```reason
  let {traits , _ } = elAgilCamello;
  let { _ , nation} = theToughCamel;
  /* bien sûr la notation pointée est possible */
  let toughNation = theToughCamel.nation;
```

Le `_` signifie simplement qu'on ne souhiate pas garder de nom vers la donnée, mais on pourrait récupérer toutes les données par destructuration, et même les renommer :

```reason
  let {traits as agilTraits, nation as agilNation } = elAgilCamello;
```

Il est possible de faire la même chose sur les n-upplets :

```reason
  let a : point3D = (3.,2.,1.);
  let (fst, _, _) = a;
```

Le pattern matching devient vraiment très puissant avec les types sommes :

```reason
  let toInt : traitScoreToInt = (ts) => switch(ts){
    | Two => 2
    | Three => 3
    | Five => 5
  };
```

Le compilateur est capable de détecter que le pattern matching n'est pas exhaustif et vous remonte un warning

```sh
    Warning number 8

    You forgot to handle a possible case here, for example:
    Four
```

Après correction :

```reason
  let toInt : traitScoreToInt = (ts) => switch(ts){
    | Two => 2
    | Three => 3
    | Four => 4
    | Five => 5
  };
```

Pour créer un traitScore depuis un int, nous devons tenir compte du fait que nous n'avons que 4 valeurs légales :

```reason
  let fromInt : int => option(traitScore) = (score) => switch(score){
    | 2 => Some(Two)
    | 3 => Some(Three)
    | 4 => Some(Four)
    | 5 => Some(Five)
    | _ => None
  };
```

le pattern `_` permet de définir **tous les autres cas**. Si nous ne sommes pas entre 2 et 5, nous ne pouvons pas convertir le type `int`. Le constructeur `None` du type `option('a)` permet de représenter l'absence de valeur.

Dans le prochain billet, nous verrons comment le système de modules de ReasonML nous permet de structurer notre code.

# Annexes

![Vodacce banner](../img/charlie-creber-vodacce-banner.jpg) © [Charlie Fox](https://tanzenkat.artstation.com/)

- [7th Basic Rules](http://johnwickpresents.com/wp-content/uploads/2017/02/basic-rules-setting-20170110.pdf)
- [7th Basic Rules Characters](http://johnwickpresents.com/wp-content/uploads/2017/02/basic-rules-characters-20170110.pdf)
- [7th Basic Rules Playing the game](http://johnwickpresents.com/wp-content/uploads/2017/02/basic-rules-playing-the-game-20170110.pdf)
- [Blog du studio Agate](https://agate-rpg.blogspot.com/search/label/7th%20Sea)
