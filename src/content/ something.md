+++
title = "Pipe macro en Rust"
date = 2019-03-29
+++

Ceci est un article de boilerplate.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
Ceci est un article de boilerplate.
De vrais articles arrivent bientôt.
De vrais articles arrivent bientôt.

```rust

pub macro_rules! pipe {
    ( $last:expr ) => { $last };
    ( $head:expr, $($tail:expr), +) => {
        pipe_two($head, pipe!($($tail),+))
    };
}

fn pipe_two<A, B, C, G, F>(f: F, g: G) -> impl Fn(A) -> C
where
    F: Fn(A) -> B,
    G: Fn(B) -> C,
{
    move |x| g(f(x))
}
```
