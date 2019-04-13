+++
title = "Opérateur pipe en Rust ?" 
date = 2019-03-29
[taxonomies]
tags = ["Rust"]
+++

L'absence d'opérateur de composition, similaire au `.` de Haskell, ou de pipeline similaire au `|>` de ReasonML et Ocaml, est assez frustrante lors qu'on essait de faire du code Rust déclaratif.

Il est possible d'envisager la _dot notation_ mais d'une part ce n'est pas totalement satisfaisant et d'autre part cela nécessite d'implémenter des traits pour chacun des types de données qui composent le flux de traitement.

Heureusement la programmation générique et les macros de **Rust** peuvent nous aider, à implémenter la composition assez facilement :

```rust

// function used to compose
fn compose_two<A, B, C, G, F>(f: F, g: G) -> impl FnOnce(A) -> C
where
    F: FnOnce(A) -> B,
    G: FnOnce(B) -> C,
{
    move |x| g(f(x))
}

// composition macro
macro_rules! compose {
    ( $last:expr ) => { $last };
    ( $head:expr, $($tail:expr), +) => {
        compose_two($head, compose!($($tail),+))
    };
}
```

Maintenant on peut composer des fonctions ainsi :

```rust
fn main() {
    let double = |x| x * 2;
    let add2 = |x| x + 2;
    let double_then_add2 = compose!(double, add2);
    println!("Result is {}", double_then_add2(10));
}
```

Grâce à notre macro `compose!`, nous pouvons également créer une nouvelle macro `pipe!` :

```rust

// function needed to infer type
fn pipe_two<A, B, F>(a : A, f: F) -> B
where
    F: FnOnce(A) -> B,
{
    f(a)
}

// pipe macro
macro_rules! pipe {
    ( $last:expr ) => { $last };
    ( $head:expr, $($tail:expr), +) => {
        pipe_two($head, compose!($($tail),+))
    };
}
```

Dorenavant nous pouvons directement pipeliner nos fonctions ainsi :

```rust
fn main() {
    let double = |x| x * 2;
    let add2 = |x| x + 2;
    println!("Result is {}", pipe!(double(10), add2));
    println!("Result is {}", pipe!(10, double, add2));
}
```

Implémenter un opérateur infixe est un peu plus complexe parce que Rust limite les opérateurs surchargeables à certains opérateurs via le module [std::ops](https://doc.rust-lang.org/std/ops/index.html), malheureusement `|>` n'en fait pas parti, cependant il est possible d'utiliser `|` ce qui nous rappelera le pipelining Linux.

Un autre point à prendre en compte est que nous avons besoin d'un type pour encapsuler nos données, si on veut éviter d'implémenter le trait [BitOr](https://doc.rust-lang.org/std/ops/trait.BitOr.html) pour chaque type initiant un pipelining.

```rust
// Need a wrapper to implement pipe operator
struct Scalar<T>(T);

use std::ops::BitOr;
impl<A, B, F> BitOr<F> for Scalar<A>
    where F: FnOnce(A) -> B
{
    type Output = Scalar<B>;

    fn bitor(self, f: F) -> Scalar<B> {
        Scalar(f(self.0))
    }
}

// Need an unwrapping function
impl<T> Scalar<T> {
    fn unwrap(self) -> T{
        self.0
    }
}
```

Ce qui nous permet enfin d'écrire :

```rust
fn main() {
    let double = |x| x * 2;
    let add2 = |x| x + 2;
    println!("Result is {}", (Scalar(10) | double | add2).unwrap());
}
```

On peut donc conclure qu'avec peu de code boilerplate, il est relativement aisé de composer des fonctions en Rust. Pour ma part, je trouve qu'implémenter les opérateurs infixe amène une complexité supplémentaire à cause de la nécessité de mettre en place les _wrapping_ et _unwrapping_, c'est pourquoi je préfère utiliser les macros dans mon code.
