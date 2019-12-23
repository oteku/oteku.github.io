+++
title = "ReasonML : les modules" 
date = 2019-12-23
draft = false
[taxonomies]
tags = ["ReasonML"]
+++

ReasonML intègre un système de **programmation modulaire**. Les modules offrent un mécanisme d'encapsulation et permettent d'organiser le code en unités logiques, en fournissant des espaces de noms (namespaces) utiles lors de leur utilisation. ReasonML propose un système de modules récursifs et paramétrables très puissant qui permet de fournir une grande généricité au code.

En ReasonML, tout le code est encapsulé dans des modules. Si nous plaçons l'ensemble du code du [premier billet](../reasonml-adt) dans un fichier `Hero.re`, cela définit automatiquement un module `Hero`.

<!-- more -->

> Ce billet est le second de la série d'articles [ReasonML : la série](../reasonml-serie/#un-programme-reason-able)

_Le nom d'un module commence toujours par une majuscule, la convention veut que l'on nomme les fichiers ReasonML en commençant également par une majuscule mais ce n'est pas une obligation : le fichier `hero.re` aurait également définit le module `Hero`_

# Déchirer le voile

## Relation à OCaml

ReasonML est une syntaxe de OCaml : à ce titre il est souvent possible de transposer du OCaml en ReasonML et vice-versa. Si dans votre apprentissage vous pensez manquer de ressource en ReasonML, n'hésitez pas à explorer les ressources OCaml. Ce sera probablement le cas si vous cherchez à approfondir le système de modules.

Au moment où j'écris ce billet les écarts sont minimes :

- ReasonML intègre JSX directement dans sa syntaxe, ceci n'est pas prévu d'êrte intégré dans OCaml
- OCaml dispose de [binding operators](http://caml.inria.fr/pub/docs/manual-ocaml/manual046.html) pour le code monadique qui devraient à terme être implémentés en ReasonML

Au démarrage, l'outil [Try](https://reasonml.github.io/en/try) permet de transposer le code OCaml en ReasonML ou ReasonML en OCaml, ainsi que le code JS généré par Buckelscript. C'est très utile.

## Sketche ton ReasonML

Cet article est disponible sous forme de [sketchbook](https://sketch.sh/s/hADE8AVnCq6LSQZVmTHf4D/).

## Règles de nommage

- Le nom des types et des bindings commencent obligatoirement par une minuscule.
- Le nom des modules et des types de modules commencent obligatoirement par une majuscule.

Il n'y a pas de convention sur le nommages entre `camelCase` et `snake_case` : il est courant de voir les deux dans un projet ReasonML car la librairie standard est issue de OCaml où la norme est le `snake_case` alors que `Buckelscript` et d'autres librairies issues de la communauté javascript utilise le `camelCase` par homogénéité avec les pratiques JS.

Il n'y a pas de bon choix entre les deux, je vous recommande donc d'en faire un et de vous y tenir pour votre code, sachant que vous utiliserez forcéménet à un moment une librairie qui aura fait un choix différent.

## Open modules

Pour accèder au contenu d'un module, il est possible de l'ouvrir. Plutôt que d'écrire :

```reason
    let agilNation = Hero.elAgilCamello.nation;
```

On peut écrire :

```reason
    open Hero;
    let agilNation = elAgilCamello.nation;
```

Le contenu du module est visible dans le _scope_. Ci dessus dans l'ensemble du fichier mais il est possible d'avoir un scope par expression :

```reason
    let agilBrawnInt = Hero.(elAgilCamello.traits.brawn |> toInt);
```

ou de créer un scrope limité :

```reason
    /* module non ouvert ici */
    {
      open Hero;
      let agilBrawnInt = elAgilCamello.traits.brawn |> toInt;
    }
    /* module non ouvert ici */
```

## Namespaces

La dimension espaces de nom des modules ReasonML est assez limitée : vous n'avez pas de possibilité de les regrouper dans des packages et vous ne pouvez pas compiler un programme qui contient deux modules du même nom. Cela peut devenir contraignant quand vous travaillez sur des grands projets.

De la même manière que nous avons vu qu'il était possible de faire des alias de types, il est également possible de faire des alias de modules. Un technique courante est de faire de [packed modules](https://blog.janestreet.com/better-namespaces-through-module-aliases/), c'est à dire un module regroupant des alias de module:

```reason
/* Supposant que nous sommes dans Core_kernel.re */
    module List = Core_kernel_list;
    module Array = Core_kernel_array;
```

et dans un autre fichier on peut faire

```reason
    open Core_kernel;
    /* List.filter ci-dessous se réfère au module Core_kernel.List et non au module List fournit par le compilateur, issu du module Pervasives */
    let dropZeros = l => List.filter(l, ~f=x => x != 0);
```

# Franchir le portail

## Modules imbriqués

Les modules peuvent s'imbriquer : nous avons vu que chaque fichier crée un module, mais il est également possible de déclarer des sous-modules :

```reason
/* Ceci est le fichier Hero.re */
    /* On déclare un sous-module Hero.Nation */
    module Nation = {
        type trait =
            | Brawn
            | Finesse
            | Resolve
            | Wits
            | Panache;

        type t =
            | Avalon(trait)
            | Inismore(trait)
            | TheHighlandMarches(trait)
            | Castille(trait)
            | Eisen(trait)
            | Montaigne(trait)
            | Sarmatia(trait)
            | Ussura(trait)
            | Vesten(trait)
            | Vodacce(trait);
    };

    /* On déclare un sous-module Hero.Traits */
    module Traits = {
        /* On déclare un sous-module Hero.Traits.Score */
        module Score = {
            type t =
            | Two
            | Three
            | Four
            | Five;

            let toInt = ts =>
                switch (ts) {
                    | Two => 2
                    | Three => 3
                    | Four => 4
                    | Five => 5
                };

            let fromInt = score =>
                switch (score) {
                    | 2 => Some(Two)
                    | 3 => Some(Three)
                    | 4 => Some(Four)
                    | 5 => Some(Five)
                    | _ => None
                };
        };

        type t = {
            brawn: Score.t,
            finesse: Score.t,
            resolve: Score.t,
            wits: Score.t,
            panache: Score.t,
        };
    };

    type t = {
    traits: Traits.t,
    nation: Nation.t,
    };
```

Vous remarquerez le nommmage des types `t` : il s'agit d'une convention largement utilisée dans les écosystèmes ReasonML / OCaml, où le type nommé `t` désigne le type principal habitant le module. On utilise `Nation.t` plutôt que `Nation.nation` bien que ce ne soit pas une obligation.

## Signtures

Les modules sont eux même statiquement typés statiquement. Il est donc possible de spécifier des types de modules. Pour notre exemple, nous décidons de créer un module `Traits` dans un fichier `Traits.re` :

```reason
    module type ScoreType = {
        type t =
            | Two
            | Three
            | Four
            | Five;
        let toInt: t => int;
        let fromInt: int => option(t);
    };

    module Score: ScoreType = {
        type t =
            | Two
            | Three
            | Four
            | Five;
        let toInt = ts =>
            switch (ts) {
                | Two => 2
                | Three => 3
                | Four => 4
                | Five => 5
            };
        let fromInt = score =>
            switch (score) {
                | 2 => Some(Two)
                | 3 => Some(Three)
                | 4 => Some(Four)
                | 5 => Some(Five)
                | _ => None
            };
        let return: t => t = value => value;
    };
```

On parle en général de signature ou d'interface car le `module type` est en réalité le _contrat public_ que doit remplir un module de ce type. Seul les types et bindings déclarés dans la signature sont accessibles quand on ouvre le module. Dans notre exemple `Score.t`, `toInt` et `fromInt`. En revanche `return` n'est accessible que dans la scope de la déclaration du module, même si `Score` était ouvert.

Il est possible également d'isoler la signature d'un module via un fichier `.rei`

```reason
/* Traits.rei */
module Score: {
  type t =
    | Two
    | Three
    | Four
    | Five;
  let toInt: t => int;
  let fromInt: int => option(t);
};

type t = {
  brawn: Score.t,
  finesse: Score.t,
  resolve: Score.t,
  wits: Score.t,
  panache: Score.t,
};
```

```reason
/* Traits.re */
module Score = {
  type t =
    | Two
    | Three
    | Four
    | Five;
  let toInt = ts =>
    switch (ts) {
    | Two => 2
    | Three => 3
    | Four => 4
    | Five => 5
    };
  let fromInt = score =>
    switch (score) {
    | 2 => Some(Two)
    | 3 => Some(Three)
    | 4 => Some(Four)
    | 5 => Some(Five)
    | _ => None
    };
  let return: t => t = value => value;
};

type t = {
  brawn: Score.t,
  finesse: Score.t,
  resolve: Score.t,
  wits: Score.t,
  panache: Score.t,
};
```

## Abstraction

Il est possible d'abstraire les types contenus dans un `module type` :

```reason
    module type ScoreType = {
        type t;
        let toInt: t => int;
        let fromInt: int => option(t);
    };
```

Ici `t` est abstrait, un module de type `ScoreType` devra fournir un type concret pour `t`.

Dans une approche de _programmation par contrat_ (interface based programming), il peut être intéressant de ne pas définir de type concret dans le contrat. Cela permet de retarder au moment de l'implémentation du contrat le choix à faire.

Souvenez-vous, nous nous étions posé des questions sur la manière de concevoir le type `Score.t` qui correspond aux entiers de 2 à 5. Mais au final, au moment de la définition du contrat nous n'avons à nous poser que question de savoir quelles sont les interactions possible entre ce type et le monde extérieur :

```reason
    module type ScoreType = {
        type t;
        /* Quelques soit le choix on se doute qu'on devra intéragir avec des int */
        let toInt: t => int;
        let fromInt: int => option(t);
        /* on souhaite avoir une arithmétique basique sans convertir en int à l'extéieur */
        let (+) : (t, t) => option(t);
        let (-) : (t, t) => option(t);
        /* on souhaite avoir une arithmétique basique sans convertir en int à l'extéieur */
        let print : t => string;
    };
```

Nous laissans plus tard le choix de l'implémentation avec un variant :

```reason
    module ScoreVariant: ScoreType = {
         type t =
            | Two
            | Three
            | Four
            | Five;
        let toInt = ts =>
            switch (ts) {
            | Two => 2
            | Three => 3
            | Four => 4
            | Five => 5
            };
        let fromInt = score =>
            switch (score) {
            | 2 => Some(Two)
            | 3 => Some(Three)
            | 4 => Some(Four)
            | 5 => Some(Five)
            | _ => None
            };
        let (+) = (score1, score2) => toInt(score1) + toInt(score2) |> fromInt ;
        let (-) = (score1, score2) => toInt(score1) - toInt(score2) |> fromInt ;
        let print = score => toInt(score) |> string_of_int;
    };
```

ou avec int :

```reason
    module ScoreInt: ScoreType = {
        type t = int;
        let toInt = ts => ts;
        let fromInt = score =>
            if (score >= 2 && score <= 5) {
            Some(score);
            } else {
            None;
            };
        let (+) = (score1, score2) => toInt(score1) + toInt(score2) |> fromInt;
        let (-) = (score1, score2) => toInt(score1) - toInt(score2) |> fromInt;
        let print = score => toInt(score) |> string_of_int;
    };
```

L'abstraction a pour intérêt également d'obfusquer le type de `t` à l'extérieur de l'implémentation du module et donc `ScoreInt.t` est différent de `int`, par exemple il n'est pas possible d'écrire :

```reason
    let printScore: ScoreInt.t => string = aScore => ScoreInt.(print(aScore));

    printScore(4); /* ne compile pas */
```

qui produira une erreur de compilation

```sh
    printScore(4);

    This type doesn't match what is expected.

    This type: int
    Expecting: ScoreInt.t
```

Au final, l'abstraction nous fournit une solution plus simple et aussi sûre que le variant pour nous permettre de représenter un sous-ensemble parmis les entiers.

Dans le prochain article nous initialiserons notre projet.

# Le mal du passage

![Porte banner](../img/charlie-creber-montaigne-banner.jpg) © [Charlie Creber](https://tanzenkat.artstation.com/)

Jusqu'ici nous avons vu l'intérêt des modules pour structurer le code et sa conception.

## Module d'ordre supérieur

Il existe une stratification entre le langage principal (les valeurs et les types) et le langage de module (les modules et les type de modules), ce qui fait qu'on ne peut pas directement utiliser un module dans une variable ou un paramètre de fonction. Pour cela ReasonML fournit une syntaxe spécifique pour pouvoir bénéficier de module d'ordre supérieur (First-Class Module) :

```reason
    module type Scalar = {
        type t;
        let value: t;
    };

    let scalar5: module Scalar with type t = int =
    (module
    {
        type t = int;
        let value = 5;
    });

    module ScalarY: Scalar with type t = char = {
        type t = char;
        let value = 'Y';
    };

    let scalarY: module Scalar = (module ScalarY);

    let getValue = m => {
        module M = (val m: Scalar with type t = int);
        M.value;
    };
```

L'opérateur `with` permet d'ajouter des contraintes dans l'équiation de type du `module type`. Pratiquement cela nous permet ici de lever l'abstraction pour obtenir par exemple `ScarlarY.t = char`. Cela peut également permettre d'exprimer des contraintes entre plusieurs modules.

## Les Foncteurs

ReasonML dispose aussi de modules fonctionnels, appelé foncteurs (functors). Il s'agit simplement de modules paramétrés par d'autres modules :

```reason
    module IncrementChar = (X: Scalar with type t = char) => {
        type t = X.t;
        let value = Char.code(X.value) + 1 |> Char.chr;
    };

    module ScalarZ = IncrementChar(ScalarY);

    module IncrementInt = (X: Scalar with type t = int) => {
        type t = X.t;
        let value = X.value + 1;
    };

    module Scalar6 = IncrementInt((val scalar5: Scalar with type t = int));

```

> Ces foncteurs ne sont ni les [foncteurs Haskell](https://wiki.haskell.org/Functor) (Functor typeclass), ni les [foncteurs C++](https://en.cppreference.com/w/cpp/utility/functional) (function Objects)

**Pourquoi les appeler foncteurs alors ?** Dans la théorie des catégories, une catégorie contient des morphismes, qui sont une généralisation des fonctions telles que nous les connaissons, et un foncteur est mappé entre les catégories. De même, les modules ReasonML contiennent des fonctions et les foncteurs ReasonML sont mappés de modules en modules.

## Continuer l'exploration

Les concepts avancés tels que les First-Class module et Functors sont abordés à titre d'ouverture, mais je vous recommande vivement ces lectures pour approfondir :

- Chapitre [The module System](http://caml.inria.fr/pub/docs/manual-ocaml/moduleexamples.html) du Manuel OCaml
- Chapitre [Functors](http://dev.realworldocaml.org/functors.html) de Real World OCaml
- Chapitre [First-Class Modules](http://dev.realworldocaml.org/first-class-modules.html) de Real World OCaml
