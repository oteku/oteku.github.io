+++
title = "Gestion des erreurs en ReasonML" 
date = 2020-08-23
draft = false
[taxonomies]
tags = ["ReasonML"]
+++

Les plantages d'un programme à l'exécution sont très coûteux, surtout lorsqu'ils se produisent en production : arrêt du service, interruption d'un traitement, perte de données, ...

Dans ce billet nous allons passer en revue les différents mode de gestion des erreurs, et comment les traiter avec ReasonML.

<!-- more -->

> Bien que pouvant être lu indépendemment, ce billet est le cinquième de la série d'articles [ReasonML : la série](../reasonml-serie/#un-programme-reason-able)

# Tout va bien se passer ... ou presque

## Dégainer et frapper

Nous voudrions que notre héro :

1. dégaine son arme
2. vise son ennemi
3. frappe l'ennemi visé

A chaque étape de cette description, une erreur peut se produire. Ces erreurs peuvent représenter soit :

- Une absence de valeur
- Un chemin alternatif dans le flux d'exécution du programme
- Une exception du runtime

## Les exceptions

De manière courante, on découvre une erreur dans notre programme à travers des exceptions. Ce modèle très utilisé pose plusieurs problèmes.

### Les exceptions sont des ombres

```reason
type weapon;
type target;
type impacted;

let draw_your_rapier : weapon = raise @@ Failure("BrokenBlade");
let targeted_ennemy : target = raise @@ Failure ("TooFar");
let hit_villain : weapon => target => impacted  = (w, t) => raise @@ Failure ("Looser");
```

> Si vous découvrez l'opérateur de composition `@@`, il permet de déduire le besoin de parenthèses : `f @@ g(x)` = `f(g(x))` = `g(x) |> f`

On remarque à cette étape que le système de type ne retranscrit pas le fait qu'une valeur puisse lancer une exception ou même qu'une fonction puisse lancer une exception. Les exceptions sont comme des **ombres** dans notre code

Si vous venez de langages tels que Java, Javascript, Typescript ou C# vous serez sans doute surpris de voir que `raise` (équivalent de throw dans ces langages), est une expression et non une instruction. En Java par exemple on aurait écrit :

```java
class Weapon {
  Weapon(){
    throw new Exception("BrokenBlade");
  }
}
class Target {
  Target(){
    throw new Exception("TooFar");
  }
}
class Impacted{
  Impacted(){
    throw new Exception("Looser");
  }
}

public class Main {
    Weapon drawYourRapier = new Weapon();
    Target targetedMonster = new Target();
    Impacted hitMonster(Weapon w, Target t) {
        return new Impacted();
    }
}
```

Le fait que `throw` soit une instruction oblige à utiliser un encodage dans la classe, ce qui rend encore plus complexe le fait de savoir à l'écriture que notre code peut produire des exceptions.

### Les erreurs sont des GOTO perdus dans l'espace et le temps

Non seulement le système de type ne fait pas apparaitre la possibilité d'exception elle même, mais en plus il n'y a aucune obligation de traiter une exception. C'est en quelque sorte un **GOTO**, un saut inconditionnel qui casse le flux d'exécution du programme... qui ne sera peut-être jamais intercepté, auquel cas il est fortement probable que le comportement du programme soit de s'arrêter de manière inattendue.

Pire encore, la programmation asynchrone peut totalement occulter une erreur qui interviendrait dans un light thread (promesse, future ou coroutine). Imaginez que nous ayons maintenant une fonction `attack` en Java :

```java
public class Main {
    Weapon drawYourRapier = new Weapon();
    Target targetedMonster = new Target();
    Impacted hitMonster(Weapon w, Target t) {
        return new Impacted();
    }
    FutureTask<Impacted> attack = new FutureTask(hitMonster(armYouBow, targetMonster));
}
```

L'erreur qui ne serait pas traitée dans la `Task` va devoir attendre qu'un `Executor` récupère l'erreur et soit la traite, soit laisse planter le programme.
Cela devient encore plus drôle si on s'intéresse aux promesses en Javascript :

```javascript
class Weapon {
  constructor() {
    throw new Exception("BrokenBlade");
  }
}
class Target {
  constructor() {
    throw new Exception("TooFar");
  }
}
class Impacted {
  constructor() {
    throw new Exception("Looser");
  }
}

const hitMonster = (w, t) => new Impacted();

const attack = new Promise((resolve, reject) => {
  const drawYourRapier = new Weapon();
  const targetedMonster = new Target();
  hitMonster(drawYourRapier, targetedMonster);
});
```

Ici comme aucune méthode `.catch` n'est attachée à la chaine de promesse, l'exception est réellement _perdue_ dans l'espace et le temps, sans même une interruption du programme. Et donc si vous compilez votre code ReasonML pour Javascript (ce que nous verrons dans un prochain billet) en utilisant les promesses JS, vous risquez d'être confronté à ce cas.

Si on revient à ReasonML native, vous utiliserez très vraissemblablement la librairie [Lwt](http://ocsigen.org/lwt/5.2.0/manual/manual)

```reason
let attack : Lwt.t(unit) = Lwt.wrap(() => {
    raise @@ Failure("Looser");
    ();
  });

Lwt.run(attack);
```

Ici on est dans une situation similaire à l'exemple Java. Grâce au hook `Lwt.async_exception_hook` une exception non traitée sera remontée au plus haut niveau et pourra interrompre l'exécution du programme.

### Try/Catch ou l'impression de sécurité

Puisque le code peut provoquer des exceptions, on a l'habitude d'utiliser un `try/catch`, comme ici en Javascript :

```javascript
class Weapon {
  constructor() {
    throw new RuntimeError("BrokenBlade");
  }
}

try {
  stuffThatMayThrowEvalError();
  otherStuffThatMayThrowRuntimeError();
  const drawYourRapier = new Weapon();
} catch (e) {
  /* Which ERROR ? Which Type ? */
}
```

Ce fonctionnement comporte plusieurs problèmes :

- A quel niveau l'exception va-t-elle être traitée ?
- Quelle est l'instruction qui a provoquée l'erreur ?
- Quel est le type de l'erreur interceptée ?

Enfin on peut décider de _ne rien faire_ et donc masquer complètement le fait qu'une exception soit intervenu durant l'exécution du programme.

Le modèle expressif a un avantage sur ce point : il oblige à traiter l'erreur ou à la passer au niveau suivant :

```reason
let draw_your_rapier: weapon =
  try(
    {
      stuff_that_may_raise_exn();
      raise @@ Failure("BrokenBlade");
    }
  ) {
  | Failure(s) =>
    print_endline(s);
    raise(Failure("unarmed"));
  | _ => raise(Failure("what was the exn ?"))
  };
```

### Que retenir des exceptions ?

Les exceptions sont un mauvais choix pour :

- Modéliser l’absence de valeur
- Modéliser une erreur fonctionnelle
- Modéliser des erreurs asynchrones

Elles peuvent être acceptable si :

- Vous n’espérez pas que quelqu’un les « catch » (contributeur d'une librairie)
- Vous savez ce que vous faites (contributeur VM)
- Vous voulez semer le chaos sur Théah !!!

## Modéliser une absence de valeur

La plupart des langages disposent d'une valeur pour représenter l'absence de valeur `Null` en Java ou `null` et `undefined` en javascript. `Uncaught TypeError: undefined has no properties ...` et `Exception in thread "main" java.lang.NullPointerException` sont la cause d'un nombre incalculable de bugs : à croire que ces valeurs ont été créées pour semer la désolation. **Bonne nouvelle, en ReasonML aucune valeur ne null n'existe**

Pourtant ces valeurs ont un sens : il est parfois nécessaire de représenter l'absence de valeur. Pour cela nous disposons, comme dans beaucoup de langages maintenant, de type optionnels.

### Option

Le type `option('a)` est un type dont les valeurs peuvent être égale à `Some('a)`, ce qui représente la présence d'une valeur, ou bien `None`, ce qui représente l'absence de valeur. Ce type est définit ainsi :

```reason
type weapon;
type target;
type impacted = | Impacted;

type option('a) =
  | Some('a)
  | None;

let draw_your_rapier: option(weapon) = None;
let targeted_ennemy: option(target) = None;
let hit_villain: (option(weapon), option(target)) => option(impacted) =
  (ow, ot) => None;
```

Etant donné que ReasonML/OCaml fournissent ce type nativement, il n'est pas nécessaire de le déclarer, on peut ainsi écrire directement :

```reason
type weapon;
type target;
type impacted = | Impacted;

let draw_your_rapier: option(weapon) = None;
let targeted_ennemy: option(target) = None;
let hit_villain: (option(weapon), option(target)) => option(impacted) =
  (ow, ot) => None;
```

Grâce au pattern matching on peut traiter les valeurs optionnelles :

```reason
let hit_villain_pattern_match = (ow, ot) =>
  switch (ow) {
  | None => None
  | Some(_) =>
    switch (ot) {
    | None => None
    | Some(_) => Some(Impacted)
    }
  };
```

Cela reste assez verbeux, on peut facilement faire la même chose grâce au `bind` (appelé _flatmap_ ou _and_then_ dans d'autres langages) du module `Option` de ReasonML. On remarquera que cette syntaxe resemble beaucoup aux chaines de promesses en javascript :

```reason
let hit_villain_bind = (ow, ot) =>
  Option.bind(ow) @@
    (_ => Option.bind(ot) @@
      (_ => Some(Impacted)));
```

Pour rendre cela plus lisible, il est courant d'avoir recours l'opérateur infix de bind : `>>=`.
Comme la librairie standard n'intègre pas encore cet opérateur pour le module Option nous devrons le définir (très simplement), pour pouvoir l'utiliser :

```reason
let (>>=) = Option.bind; /* Infix operator for bind */

let hit_villain_dot_free = (ow, ot) =>
  ow >>= (_ => ot) >>= (_ => Some(Impacted));
```

Il est également possible de rendre la manipulation plus lisible encore grâce à l'opérateur monadique `let*`.
Comme la librairie standard n'intègre pas encore cet opérateur pour le module Option nous devrons également le définir :

```reason
let (let*) = Option.bind;

let hit_villain_let_star = (ow, ot) => {
  let* _used = ow ;
  let* _targeted = ot ;
  Some(Impacted)
};
```

Dans tout les exemples, la fonction retournera `None` SI `ow` OU `ot` valent `None`.

Les différentes notation sont du sucre syntaxique, à vous de choisir celle qui vous convient. Pour ma part, j'ai tendance à apprécier fortement le `let*`

#### Apparté sur le `;`

Si le dernier exemple vous semble bizarre, en ReasonML, il faut bien comprendre que le point-vigurle n'a pas le même sens qu'en Java ou Javascript. L'utilisation du `;` homogénéifie l'écriture de code, bien qu'il puisse représenter 3 trois cas différents :

1. La soumission et l'évaluation d'un input quand on utilise un toplevel tel que `rtop` (le REPL de Reason, similaire à utop pour OCaml). En OCaml, l'équivalent est un double point-virgule `;;`

2. Du sucre syntaxique pour le scope local, en ReasonML :

```reason
{
  let foo = "FOO";
  let foobar = foo ++ "BAR";
}
```

est équivalent en OCaml à :

```ocaml
let _ = let foo = "FOO" in
let foobar = foo ^ "BAR" in ()
```

3. L'unification la syntaxe des modules avec celle du local scope. En ReasonML :

```reason
module FooBar = {
  type t = string;
  let value: t = "FooBar";
};
```

est équivalent en OCaml à :

```ocaml
module FooBar =
  struct
    type t = string
    let value: t = "FooBar"
  end
```

### Que retenir des options ?

Les options servent à modéliser l'absence de valeur. Dans le contexte d'un langage disposant d'[ADT](../reasonml-adt), elles sont faciles à utiliser, surtout avec la syntaxe `let*` ou l'opérateur infixe `>>=`.

## Modéliser une erreur potentielle

Si on utilise le type `option('a)` pour modéliser une erreur, on perd toute information sur l'erreur. On aimerait un type de valeur qui permette de savoir si une fonction a réussi ou échoué, et auquel cas avoir des informations sur l'erreur rencontrée.

### Result

Le type `result('a, 'b)` est un type dont les valeurs peuvent être égale à `Ok('a)`, ce qui représente la réussite du traitement, ou bien `Error('b)`, ce qui représente l'échec du traitement. Ce type est définit ainsi :

```reason
type weapon = string;
type target = string;
type impacted =
  | Impacted(target);

type result('a, 'b) =
  | Ok('a)
  | Error('b);

let arm_your_bow: result(weapon, exn) = Error(Failure("only have a rapier"));
let targeted_villain: result(target, string) = Error("too far");
```

Etant donné que ReasonML/OCaml fournissent ce type nativement, il n'est pas nécessaire de le déclarer, on peut ainsi écrire directement :

```reason
type weapon = string;
type target = string;
type impacted =
  | Impacted(target);

let arm_your_bow: result(weapon, exn) = Error(Failure("only have a rapier"));
let targeted_villain: result(target, string) = Error("too far");
```

ReasonML fournit également une fonction `bind` dans le module `Result` qui facilite la manipulation des valeurs :

```reason
let ( let* ) = Result.bind;

type weapon = string;
type target = string;
type impacted =
  | Impacted(target);

let must_be_carried = w =>
  w == "rapier" ? Ok(w) : Error(Failure("not carried"));

let hit_villain_let_star = (rw, rt) => {
  let* _used = rw;
  let* targeted = rt;
  Ok(Impacted(targeted));
};

let foo = hit_villain_let_star(must_be_carried("bow"), Ok("pirate"));
```

## Que retenir de tout ça ?

- N'utilisez pas d'exception ... la plupart du temps
- Utilisez le type `option('a)` pour représenter la possibilité d'abscence de valeur
- Utilisez le type `result('a,'b)` pour représenter la possibilité d'une erreur

Ces types ont également l'avantage d'intégrer dans le typage l'information de possibilité d'erreur qui était masqué avec les exception.
