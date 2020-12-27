+++
title = "OCaml : DnD Kata" 
date = 2020-12-27
draft = false
[taxonomies]
tags = ["OCaml"]
+++


Lorsque je découvre ou veux expliquer un concept, j'aime assez m'appuyer sur un Kata, un excercice court pour mettre en avant une pratique de programmation. Je vous propose donc le **DnD Kata**, dont l'objectif est de modéliser une équipes de personnage pour une partie du jeu de rôle Donjon et Dragons. Bien sûr modéliser l'ensemble des règles est un exercice complexe, nous nous contenterons ici de représenter un personnage par :
- son nom
- sa race
- ses compétences, incluant et bien sûr ses bonus raciaux

Une équipe est une collection de personnages, pouvant être de races différentes.

L'objectif pédagogique de ce kata est d'illustrer les [foncteurs OCaml](https://oteku.github.io/reasonml-modules/#les-foncteurs) et de démontrer comment ils contribuent à appliquer les principes S.O.L.I.D en OCaml.

<!-- more -->


## A propos de Donjon et Dragons

Donjon & Dragons a.k.a DnD est un jeu de rôle où les joueurs incarnent des héros dans un univers fantastique. L'univers principal de ce jeu est Faerûn, un continent de la planète Abeir-Toril. Nous utiliserons le système [Donjon & Dragons 5ème Édition sous la licence Open-Gaming (OGL)](https://github.com/Umbyology/OGL-SRD5).

## Nous sommes les Nains

Nous allons commencer par modéliser les Nains, l'une des races jouables de Faerûn, par leur nom.

Nous savons déjà qu'un bon moyen d'avoir un espace de noms dans OCaml est d'utiliser des modules, nous pouvons donc commencer par cette représentation :

```ocaml
module Dwarf = struct
  type t = string
end
```

Dans cette implémentation, le type du module est inféré. On peut aussi le rendre explicite en ajoutant une signature de module et en modélisant les Elfes en même temps :

```OCaml
module Dwarf : sig
  type t = string
end = struct
  type t = string
end

module Elf : sig
  type t = string
end = struct
  type t = string
end
```

A cette étape on remarque que les 2 modules partagent la même signature. Étant donné que les modules Elf et Nain représentent des héros jouables, cela semble légitime et nous préciserions que tous les héros jouables partagent la même signature. Pour ce faire, nous pouvons utiliser un type de module :


```OCaml
module type PLAYABLE = sig
  type t = string
end

module Dwarf: PLAYABLE = struct
  type t = string
end

module Elf : PLAYABLE = struct
  type t = string
end
```

Les autres modules n'ont pas besoin de connaître la forme du type `PLAYABLE.t`, ils ont seulement besoin de savoir qu'il existe et le module doit exposer des fonctions pour l'utiliser.

On appelle cela une **abstraction**, car on rend le type `t` abstrait :

```ocaml
module type PLAYABLE = sig
  type t
  val to_string : t -> string
  val of_string : string -> t
end
```

Chaque module de type PLAYABLE doit implémenter ces fonctions. Faisons le :


```ocaml
module Dwarf: PLAYABLE  = struct
  type t = {name : string}
  let to_string dwarf = dwarf.name
  let of_string name = {name}
end

module Elf : PLAYABLE = struct
  type t = string
  let to_string elf = elf
  let of_string name = name
end
```

Puisque `t` est abstrait, vous remarquerez que chaque module implémentant` PLAYABLE` peut avoir un type de concret différent pour `t`. C'est tout à fait correct tant qu'ils respectent leur contrat de type de module.

Depuis un autre module, nous ne pouvons pas accéder à une valeur concrète de `t`, mais nous pouvons créer un nain ou obtenir une représentation sous forme de `string`.


```ocaml
let gimly = Dwarf.of_string "Gimly"
let () = Dwarf.to_string gimply |> print_endline
```

## Les Héros ont des caractéristiques

Dans DnD, un héros est également représenté par ses caractéristiques :
- La Force représente la puissance physique, l'aptitude athlétique naturelle
- La Dextérité représente l'agilité, les réflexes, l'équilibre
- La Constitution représente la santé, l'endurance, la force vitale
- L'Intelligence représente l'acuité mentale, le raisonnement, la mémoire
- La Sagesse représente la perception, l'intuition, la perspicacité
- Le Charisme représente la force de personnalité, l'éloquence, le leadership

Il y a plusieurs règles optionnelles pour les caractéristiques à la création, nous n'implémenterons que celle des _Standard scores_. Au début, chaque capacité a une valeur de 10 :


```ocaml
module Abilities = struct
  type t = {
    strength : int
  ; dexterity : int
  ; constitution : int
  ; intelligence : int
  ; wisdom : int
  ; charisma : int
  }

  let init () =  {
    strength = 10
  ; dexterity = 10
  ; constitution = 10
  ; intelligence = 10
  ; wisdom = 10
  ; charisma = 10
  }
end
```

Nous pouvons ainsi faire évoluer notre module `Dwarf` :


```ocaml
module Dwarf: PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let to_string dwarf = dwarf.name
  let of_string name = {name ; abilities = Abilities.init()}
end
```

Les noms de nos fonctions ne sont plus très appropriés, nous allons donc mettre à jour le type de module `PLAYABLE` puis les modules` Elf` et `Dwarf` :


```ocaml
module type PLAYABLE = sig
  type t
  val name : t -> string
  val make : string -> t
end

module Dwarf: PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name dwarf = dwarf.name
  let make name = {name ; abilities = Abilities.init()}
end

module Elf: PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name elf = elf.name
  let make name = {name ; abilities = Abilities.init()}
end
```

## Les races donnent des modificateurs

### Les nains ont un bonus de +2 en constitution

En OCaml, les modules sont de premier ordre, cela signifie que vous pouvez utiliser module comme des valeurs. On peut donc créer un nouveau type de module pour représenter un bonus et des fonctions pour représenter un bonus de 2 :

```ocaml
module type BONUS = sig
  type t
  val value : t
end
```

Ainsi qu'une valeur qui permet d'optenir un module de ce type :

```ocaml
let bonus_2 : (module BONUS with type t = int) = (module struct
    type t = int
    let value = 2
end)
```

`bonus_2` est un module en tant que valeur. Puisque que `t` est abstrait, nous devons ajouter un  type témoin `with type t = int`.

Pour extraire la valeur du bonus, nous avons également besoin d'un getter :

```ocaml
let get_bonus b = let module M = (val (b : (module BONUS with type t = int))) in M.value
```

> Je reconnais que la syntaxe des modules de premier ordre n'est pas des plus aggréable, nous verrons que leur usage est somme toute limité. Si vous cherchez des explications supplémentaires sur vous pouvez lire : https://dev.realworldocaml.org/first-class-modules.html

Nous pouvons dorénavant écrire : 

```ocaml
module Dwarf: PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name dwarf = dwarf.name
  let make name = {name ; abilities = Abilities.init()}
  let constitution dwarf = dwarf.abilities.constitution + get_bonus bonus_2
end
```

### N'oublions pas les Elfes, Demi-Orc, Halfling ou Tieflings

Les nains ne sont pas la seule race de Faerun. Chacun a un bonus de constitution différent. Les demi-orcs ont +1 tandis que les Elfes, les Halfling et les Tieflings n'ont pas de bonus de constitution.

Lorsque les données d'une fonction varient, nous ajoutons un paramètre de fonction pour éviter la duplication de code. Nous pouvons faire de même au niveau du module. OCaml possèdes des **foncteurs** qui sont des modules fonctionnels : des fonctions de modules à module.

Nous pouvons donc créer un foncteur `Race` :

```ocaml
module Race (B : BONUS with type t = int) : PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name character = character.name
  let make name = {name ; abilities = Abilities.init()}
  let constitution_bonus = B.value (* here we get the value from module B *)
  let constitution character = character.abilities.constitution + constitution_bonus
end
```

> Se lit : le foncteur `Race` prend comme paramètre un module `B` de type `BONUS` dont le type `t` est `int` et retourne ensuite un module de type` PLAYBLE`.

Ensuite, nous pouvons facilement construire nos modules :

```ocaml
(* we add a function to manage all bonus *)
let bonus (x:int) : (module BONUS with type t = int) = (module struct
    type t = int
    let value = x
end)

(* we use our Race functor to create the five races *)
module Dwarf = Race (val bonus 2)
module Elf = Race (val bonus 0)
module Tiefling = Race (val bonus 0)
module Halfling = Race (val bonus 0)
module HalfOrc = Race (val bonus 1)
```

> Vous comprenez maintenant pourquoi nous avons introduit les modules de premier ordre précédemment. Ils facilitent le passage de valeur entre le *Type level* et le *Module level*, ce qui est très pratique ici.

### Toutes les compétences peuvent avoir des bonus

Les foncteurs ne sont pas limités à un paramètre, nous pouvons donc utiliser la même astuce pour toutes les caractéristiques :


```ocaml
module Race
    (BS : BONUS with type t = int)
    (BD : BONUS with type t = int)
    (BC : BONUS with type t = int)
    (BI : BONUS with type t = int)
    (BW : BONUS with type t = int)
    (BCh : BONUS with type t = int) : PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name character = character.name
  let make name = {name ; abilities = Abilities.init()}
  let bonus = Abilities.{
      strength = BS.value
    ; dexterity = BD.value
    ; constitution = BC.value
    ; intelligence = BI.value
    ; wisdom = BW.value
    ; charisma = BCh.value
    }
  let abilities character = Abilities.{
      strength = character.abilities.strength + bonus.strength
    ; dexterity = character.abilities.dexterity + bonus.dexterity
    ; constitution = character.abilities.constitution + bonus.constitution
    ; intelligence = character.abilities.intelligence + bonus.intelligence
    ; wisdom = character.abilities.wisdom + bonus.wisdom
    ; charisma = character.abilities.charisma + bonus.charisma
    }
end

module Dwarf = Race (val bonus 0) (val bonus 0) (val bonus 2)(val bonus 0) (val bonus 0) (val bonus 0)
```

Pour notre cas d'utilisation, ce n'est pas pratique, nous devons nous souvenir de l'ordre des bonus. Nous avons déjà un type qui représente toutes les valeurs de capacités `Abilities.t`, utilisons-le :


```ocaml
(* just create a bonus function that take a Abilities.t and return a Bonus module *)
let bonus (x:Abilities.t) : (module BONUS with type t = Abilities.t) = (module struct
    type t = Abilities.t
    let value = x
end)

(* the functor `Race` take a module `B` of type `BONUS` whom type `t` is `Abilities.t`
** as parameter and then return a module of type `PLAYBLE`  *)
module Race
    (B : BONUS with type t = Abilities.t) : PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name character = character.name
  let make name = {name ; abilities = Abilities.init()}
  let bonus = Abilities.{
      strength = B.value.strength
    ; dexterity = B.value.dexterity
    ; constitution = B.value.constitution
    ; intelligence = B.value.intelligence
    ; wisdom = B.value.wisdom
    ; charisma = B.value.charisma
    }
  let abilities character = Abilities.{
      strength = character.abilities.strength + bonus.strength
    ; dexterity = character.abilities.dexterity + bonus.dexterity
    ; constitution = character.abilities.constitution + bonus.constitution
    ; intelligence = character.abilities.intelligence + bonus.intelligence
    ; wisdom = character.abilities.wisdom + bonus.wisdom
    ; charisma = character.abilities.charisma + bonus.charisma
    }
end

(* create our Dwarf module *)
module Dwarf = Race (val bonus Abilities.{
    strength = 0
  ; dexterity = 0
  ; constitution = 2
  ; intelligence = 0
  ; wisdom = 0
  ; charisma = 0
  })
```

Pour être plus concis et explicite, nous pouvons travailler à partir d'une valeur `no_bonus` :


```ocaml
let no_bonus = Abilities.{
    strength = 0
  ; dexterity = 0
  ; constitution = 0
  ; intelligence = 0
  ; wisdom = 0
  ; charisma = 0
  }

module Dwarf = Race (val bonus Abilities.{
    no_bonus with constitution = 2
  })
module Elf = Race (val bonus Abilities.{
    no_bonus with dexterity = 2
  })
module Halfling = Race (val bonus Abilities.{
    no_bonus with dexterity = 2
  })
module Tiefling = Race (val bonus Abilities.{
    no_bonus with charisma = 2  ; intelligence = 1
  })
module HalfOrc = Race (val bonus Abilities.{
    no_bonus with strength = 2
  })
```

### Synthèse

À la fin de cette section, vous devriez avoir :


```ocaml

module Abilities = struct
  type t = {
    strength : int
  ; dexterity : int
  ; constitution : int
  ; intelligence : int
  ; wisdom : int
  ; charisma : int
  }

  let init () =  {
    strength = 10
  ; dexterity = 10
  ; constitution = 10
  ; intelligence = 10
  ; wisdom = 10
  ; charisma = 10
  }
end

module type BONUS = sig
  type t
  val value : t
end

let bonus (x:Abilities.t) : (module BONUS with type t = Abilities.t) = (module struct
                                                                   type t = Abilities.t
                                                                   let value = x
                                                                 end)

let no_bonus = Abilities.{
    strength = 0
  ; dexterity = 0
  ; constitution = 0
  ; intelligence = 0
  ; wisdom = 0
  ; charisma = 0
  }

module type PLAYABLE = sig
  type t
  val make : string -> t
  val name : t -> string
  val abilities : t -> Abilities.t
end


module Race
    (B : BONUS with type t = Abilities.t) : PLAYABLE  = struct
  type t = {name : string ; abilities : Abilities.t}
  let name character = character.name
  let make name = {name ; abilities = Abilities.init()}
  let bonus = Abilities.{
      strength = B.value.strength
    ; dexterity = B.value.dexterity
    ; constitution = B.value.constitution
    ; intelligence = B.value.intelligence
    ; wisdom = B.value.wisdom
    ; charisma = B.value.charisma
    }
  let abilities character = Abilities.{
      strength = character.abilities.strength + bonus.strength
    ; dexterity = character.abilities.dexterity + bonus.dexterity
    ; constitution = character.abilities.constitution + bonus.constitution
    ; intelligence = character.abilities.intelligence + bonus.intelligence
    ; wisdom = character.abilities.wisdom + bonus.wisdom
    ; charisma = character.abilities.charisma + bonus.charisma
    }
end

module Dwarf = Race (val bonus Abilities.{
    no_bonus with constitution = 2
  })
module Elf = Race (val bonus Abilities.{
    no_bonus with dexterity = 2
  })
module Halfling = Race (val bonus Abilities.{
    no_bonus with dexterity = 2
  })
module Tiefling = Race (val bonus Abilities.{
    no_bonus with charisma = 2  ; intelligence = 1
  })
module HalfOrc = Race (val bonus Abilities.{
    no_bonus with strength = 2
  })
```

On peut facilement ajouter n'importe quelle race, par exemple les humains on +1 à toutes les caractéristique :

```ocaml
module Human = Race (val bonus Abilities.{
    strength = 1
  ; dexterity = 1
  ; constitution = 1
  ; intelligence = 1
  ; wisdom = 1
  ; charisma = 1
  })
```

## United color of Faerûn

Chaque joueur peut jouer un personnage de race différente. Comment modéliser une équipe ?

### The companions of the Hall

> The companions est un livre de R.A. Salvatore un romancier qui a écrit de nombreuses nouvelles situées à Faerûn

Commençons par créer les personnages, nous avons déjà tout ce qu'il faut :

```ocaml
let catti = Human.make "Catti-brie"
let regis = Halfling.make "Regis"
let bruenor = Dwarf.make "Bruenor Battlehammer"
let wulfgar = Human.make "Wulfgar"
let drizzt = Elf.make "Drizzt Do'Urden"
```

Que se passe-t-il si on crée *les compagnions* :

```ocaml
❌ let companions = [catti; regis; bruenor; wulfgar;  drizzt]
```

**Error: This expression has type Halfing.t but an expression was expected of type
Human.t**

Souvenez-vous que le type de `list` est de type `type 'a t = 'a list`, moteur d'inférence set `'a = Human.t` car c'est le type du premier élément de notre liste `catti`, mais le type `regis` est `Halfing.t`.

Comment pourrions-nous aider le compilateur ? Les paramètres de type doivent être des types concrets.

```ocaml
(* won't compile PLAYABLE is a module type  *)
❌ type team = PLAYABLE.t list

(* won't compile RACE is a functor
** aka a function from module to module  *)
❌ type team = RACE.t list
```

En réalité, il n'y a rien de bien compliqué, le point principal est que les listes OCaml sont monomorphique, il nous faut donc un type unique qui puisse représenter un personnage, quelque soit sa race :

```ocaml
type buddy =
  | Dwarf of Dwarf.t
  | Elf of Elf.t
  | Halfing of Halfling.t
  | Tiefling of Tiefling.t
  | HalfOrc of HalfOrc.t
  | Human of Human.t
  
let companions = [Human catti; Halfing regis; Dwarf bruenor; Human wulfgar;  Elf drizzt]
```

Cependant il existe beaucoup d'autre race dans Faerûn, ainsi que des variante. Drizzt par exemple est en réalité un elfe noir et non un elf. Il serait plus opportun d'utiliser des [variants polymorphes](http://dev.realworldocaml.org/variants.html#scrollNav-4) afin de faciliter l'extentions de notre librairie, car nous en sommes encore à l'embrayons d'un véritable générateur de personnages :

```ocaml
let companions_final = 
    [`Human catti; `Halfing regis; `Dwarf bruenor; `Human wulfgar;  `Elf drizzt]
```

dont le type sera

```ocaml
val companions_final :
  [> `Dwarf of Dwarf.t
   | `Elf of Elf.t
   | `Halfing of Halfling.t
   | `Human of Human.t ]
  list =
  [`Human <abstr>; `Halfing <abstr>; `Dwarf <abstr>; `Human <abstr>;
   `Elf <abstr>]
```

## Take away

1. OCaml proposes des abstractions utiles pour :

- namespaces : **module**
- protocole : **module type**
- extension : **functor**
- default value or implementation : **functor** ou **first-class module**
  - functors sont des fonctions de modules à module
  - modules de premier ordre sont des valeurs et permettent de communiquer entre le type level et le module level.

2. S.O.L.I.D n'est pas uniquement une bonne pratique de POO :

- Single responsibility principle => module
- Open/closed principle => module
- Liskov substitution principle => module type
- Interface segregation principle => module type
- Dependency inversion principle => functor