+++
title = "Thead to the Future" 
date = 2019-08-07
draft = false
[taxonomies]
tags = ["rust"]
+++

Je travaille actuellement sur un robot compagon nommé [Cutii](https://www.cutii.io/cutii/) pour lequel nous avons besoins de communiquer sur port série entre le PC du robot et nos différentes cartes électronique, nous avons fait le choix il y a quelques mois d'implémenter une librairie de communication en Rust, afin de rendre plus sûrs et plus performants nos échanges. Ce billet vise à dresser un état des lieux de la gestion de communications asynchrones en Rust.

Pour illustrer les exemples, imaginons que nous ayons un protocole simplifié de communication, nous permettant de faire des **GET** et **SET** sur des valeur, en mode requête / réponse et sur port série :

```sh
# requête GET pour une valeur foo
foo?\n
# réponse à la requête GET
foo=1\n
# requête SET pour une valeur foo
foo=2\n
# réponse d'acquitement à la requête SET
foo=2\n
```

Nous considérons que les messages sont toujours traité dans l'ordre des requêtes émises et que leur réponse est immédiate.

_Ce protocole est suffisant pour les besoins de cet article, bien sûr il pourrait être remplacé par http, mqtt, enocean ou n'importe quel protocole industriel._

Outillons nous pour simuler ce protocole avec `echo`, `cat` et `socat` :

```sh
# In terminal 0, emulate a writable port /tmp/ttyS0 that passthrough the readable port /tmp/ttyS1
socat PTY,link=/tmp/ttyS0,raw,echo=0 PTY,link=/tmp/ttyS1,raw,echo=0
# In terminal 1, read the port  /tmp/ttyS0
cat -v < /tmp/ttyS0
# In terminal 2, read the port  /tmp/ttyS#
cat -v < /tmp/ttyS1
# In terminal 3, simulate the GET request
echo -ne 'foo?\n' > /tmp/ttyS0
echo -ne 'foo=1\n' > /tmp/ttyS1
echo -ne 'foo=2\n' > /tmp/ttyS0
echo -ne 'foo=2\n' > /tmp/ttyS1
```

_Implémenter la communication sur port série, ne nous intéresse pas vraiment ici, c'est un cas d'exemple qui pourrait être remplacé par des socket unix, socket tcp, ... aussi nous utiliserons la librairie [serialport](https://crates.io/crates/serialport)_

Notre objectif est bien sûr de mettre en place un processus de communication sur port série non bloquant, afin que le programme principale puisse effectuer d'autres traitements.

# Première version : les threads

Chose très intéressante avec Rust, la librairie standard dispose de plusieurs pattern intéressants pour la programmation multi-threadée :

- [Atomically Reference Counted](https://doc.rust-lang.org/std/sync/struct.Arc.html) : `Arc<T>` fournit un _ownership_ partagé pour une valeur de type `T`, _thread-safe_ et allouée dans la _heap_
- [Mutex](https://doc.rust-lang.org/std/sync/struct.Mutex.html) : un mécanisme d'exclusion mutuelle pour protéger des données partagées entre plusieurs thread
- [Canaux de communication orientés messages](https://static.rust-lang.org/doc/master/std/sync/mpsc/index.html) : le module `mspc` fournit les primitives de queue de communication _First In First Out_ _multi-producer, single-consumer_ qui permettent à un thread de collecter des informations issus de plusieurs autres threads.

Faisons un premier programme qui écrit la requête `foo?\n` sur le port `/tmp/ttyS0` et qui pour chaque requête envoie une valeur de foo incrémentée de 1, en utilisant un **Mutex**.

Le cheminement du programme peut être schématisé ainsi :

\_thread1 _-[/tmp/ttyS0] "foo?\n" [/tmp/ttyS1]->_ \_thread2 _- foo++ ->_ thread3 _- [/tmp/ttyS0] "foo=1\n" [/tmp/ttyS1] ->_ \_thread0 _-> [stdout] "foo=1\n"_

```rust
extern crate serialport;

use serialport::prelude::*;
use std::io;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use std::{env, str, thread};

const TTY0: &str = "/tmp/ttyS0";
const TTY1: &str = "/tmp/ttyS1";
fn main() {
    let mut args = env::args();
    let tty0_path = args.nth(1).unwrap_or_else(|| TTY0.into());
    let tty1_path = args.nth(2).unwrap_or_else(|| TTY1.into());

    let mut settings: SerialPortSettings = Default::default();
    settings.timeout = Duration::from_millis(10);
    settings.baud_rate = 20;

    // send foo? requests and print responses
    match serialport::open_with_settings(&tty0_path, &settings) {
        Ok(mut writer) => {
            let mut reader = writer.try_clone().expect("Failed to clone");

            // read the port and write to stdout
            let _thread0 = thread::Builder::new()
                .name("reader0".to_string())
                .spawn(move || {
                    // a buffer of bytes
                    let mut serial_buf: Vec<u8> = vec![0; 1000];
                    loop {
                        match reader.read(serial_buf.as_mut_slice()) {
                            Ok(t) => {
                                let newline = &serial_buf[..t].iter().position(|b| *b == b'\n');
                                if let Some(n) = newline {
                                    let (line, _) = serial_buf.split_at(*n);
                                    println!(
                                        "reader0 thread : {}",
                                        &String::from_utf8(line.to_vec()).unwrap()
                                    );
                                }
                            }
                            Err(ref e) if e.kind() == io::ErrorKind::TimedOut => (),
                            Err(e) => eprintln!("{:?}", e),
                        }
                        thread::sleep(Duration::from_millis(50));
                    }
                });

            let _thread1 = thread::Builder::new()
                .name("writer0".to_string())
                .spawn(move || loop {
                    writer.write(b"foo?\n").expect("Failed to write");
                    thread::sleep(Duration::from_millis(50));
                });
        }
        Err(e) => {
            eprintln!("Failed to open \"{}\". Error: {}", TTY0, e);
            ::std::process::exit(1);
        }
    }

    // Increment foo value on each request
    match serialport::open_with_settings(&tty1_path, &settings) {
        // get the serial port for writer thread
        Ok(mut writer) => {
            // clone serialport for reader thread
            let mut reader = writer.try_clone().expect("Failed to clone");
            // mutex to exchange data between threads
            let counter: Arc<Mutex<i32>> = Arc::new(Mutex::new(0));
            // clone Arc to access pointer from another thread
            let counter2 = counter.clone();
            // read the port and write to stdout
            let _thread2 = thread::Builder::new()
                .name("reader1".to_string())
                .spawn(move || {
                    let mut serial_buf: Vec<u8> = vec![0; 1000];
                    loop {
                        match reader.read(serial_buf.as_mut_slice()) {
                            Ok(t) => {
                                let (line, _) = serial_buf.split_at(t);
                                // get a lock on mutex and increment the value
                                let mut data = counter.lock().unwrap();
                                *data += 1;
                            }
                            Err(ref e) if e.kind() == io::ErrorKind::TimedOut => (),
                            Err(e) => eprintln!("{:?}", e),
                        }
                        thread::sleep(Duration::from_millis(50));
                    }
                });

            let thread3 = thread::Builder::new()
                .name("writer1".to_string())
                .spawn(move || loop {
                    let foo_value = *counter2.lock().unwrap();
                    let mut write_buf: Vec<u8> = vec![0; 1000];
                    write_buf.append(&mut b"foo=".to_vec());
                    write_buf.append(&mut foo_value.to_string().as_bytes().to_vec());
                    write_buf.append(&mut b"\n".to_vec());
                    writer.write(write_buf.as_slice()).expect("Failed to write");
                    thread::sleep(Duration::from_millis(50));
                });
            thread3.unwrap().join().unwrap(); //need to handle the last thread to avoid exit the program
        }
        Err(e) => {
            eprintln!("Failed to open \"{}\". Error: {}", TTY1, e);
            ::std::process::exit(1);
        }
    }
}
```

Le **Mutex** est pratique pour partager une valeur entre plusieurs threads mais ne permet pas de savoir _quand_ une valeur est mise à jour. Le code ci-dessus ne fonctionne que parce que les temporisations de threads sont égales, ce qui n'est pas satisfaisant. Nous pouvons améliorer cela grace au **mpsc**, en remplaçant le code des thread2 et thread3 par

```rust
...
// Increment foo value on each request
    match serialport::open_with_settings(&tty1_path, &settings) {
        // get the serial port for writer thread
        Ok(mut writer) => {
            // clone serialport for reader thread
            let mut reader = writer.try_clone().expect("Failed to clone");
            let (tx, rx) = channel();
            // read the port and write to stdout
            let _thread2 = thread::Builder::new()
                .name("reader1".to_string())
                .spawn(move || {
                    let mut serial_buf: Vec<u8> = vec![0; 1000];
                    let mut data: i32 = 0;
                    loop {
                        match reader.read(serial_buf.as_mut_slice()) {
                            Ok(t) => {
                                let (_line, _) = serial_buf.split_at(t);
                                // increment the thread scoped var
                                data += 1;
                                tx.send(data).unwrap();
                            }
                            Err(ref e) if e.kind() == io::ErrorKind::TimedOut => (),
                            Err(e) => eprintln!("{:?}", e),
                        }
                        thread::sleep(Duration::from_millis(50));
                    }
                });

            let thread3 = thread::Builder::new()
                .name("writer1".to_string())
                .spawn(move || loop {
                    let foo_value = rx.recv().unwrap(); // wait until received a value from tx
                    let mut write_buf: Vec<u8> = vec![0; 1000];
                    write_buf.append(&mut b"foo=".to_vec());
                    write_buf.append(&mut foo_value.to_string().as_bytes().to_vec());
                    write_buf.append(&mut b"\n".to_vec());
                    writer.write(write_buf.as_slice()).expect("Failed to write");
                });
            thread3.unwrap().join().unwrap(); //need to handle the last thread to avoid exit the program
        }
        Err(e) => {
            eprintln!("Failed to open \"{}\". Error: {}", TTY1, e);
            ::std::process::exit(1);
        }
    }
```

Nous avons maintenant réellement le fonctionnement voulu. Le fonctionnement de _channel_ fournit nativement par Rust est vraiment pratique pour la communictaion entre threads, néanmoins on s'apperçoit avec ce cas trivial que cela demande beaucoup de code boilerplate et surtout on peut vite se perdre à la lecture du code quand on cherche à synchroniser plusieurs threads à partir de la mise à jour d'une donnée.

_NB : on accepte ici qu'une requête, il faudrait parser réellement les requêtes pour implémenter intégralement notre protocole._

# Seconde version : les futures

Une [Future](https://doc.rust-lang.org/std/future/trait.Future.html), parfois appellée _promesse_ dans d'autres langages, est un calcul asynchrone pouvant produire une valeur. Une **Future** en Rust est évaluée de manière paresseuse (Lazy evaluation), c'est à dire qu'elle ne fait rien à moins d'être _amenée_ à l'état `Ready`, pour cela elle doit être activement `poll`. Ce fonctionnement peut surprendre si vous êtes habitué aux promesses de javascript ou futures de java. Il est donc nécessaire de construire également un `executor` pour utiliser une **Future**.

Si on voulait réécrire l'équivalent des thread3 et 4, en considérant que nous avons un client séparé qui envoie les requête `foo?\n`, on voudrait avoir quelque chose de ce style :

```rust
// Conceptual code : doesn't work as is
fn main() {
    match serialport::open_with_settings(&tty1_path, &settings) {
        Ok(mut writer) => {
        let mut reader = writer.try_clone().expect("Failed to clone");
        let (executor, spawner) = new_executor_and_spawner();
            spawner.spawn(
                SerialRead{
                    sp: &*writer,
                    shared_state: Arc::new((Mutex::new(None))
                }.and_then(| buffer | SerialWrite{
                    sp: &*writer,
                    data: build_write_buff_from_read_buff(buffer), //build answer from request
                    shared_state: Arc::new((Mutex::new(None))
                }).map_err(|_| println!("failed"));
            );
            drop(spawner);
            executor.run();
                }
        Err(e) => {
            eprintln!("Failed to open \"{}\". Error: {}", TTY1, e);
            ::std::process::exit(1);
        }
    }
}
```

Utiliser les futures simplifie grandement la lecture du code au regard de la gestion des threads avec mpsc, mais créer ses Future n'est pas chose aisé. La struture `SerialRead`, par exemple, qui représente la lecture asynchrone sur le port série et qui implémente le trait `Future`, ressemblerait à ça

```rust
use std::future::Future;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};
use std::pin::Pin;

pub struct SerialRead<'a> {
    sp: &'a dyn SerialPort,
    shared_state: Arc<Mutex<SharedState>>,
}

struct SharedState {
    waker: Option<Waker>,
}

impl Future for SerialRead<'_> {
    type Output = Vec<u8>;

    fn poll(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Self::Output> {
        let mut serial_buf: Vec<u8> = vec![0; 1000];
        let mut shared_state = self.shared_state.lock().unwrap();
        if let Ok(t) = self
            .sp
            .try_clone()
            .expect("Failed to clone")
            .read(serial_buf.as_mut_slice())
        {
            let newline = &serial_buf[..t].iter().position(|b| *b == b'\n');
            if let Some(n) = newline {
                let (line, _) = serial_buf.split_at(*n);
                Poll::Ready(line.to_vec())
            } else {
                // The serial does not yet have data
                shared_state.waker = Some(cx.waker().clone());
                Poll::Pending
            }
        } else {
            // The serial port cannot be block for read.
            shared_state.waker = Some(cx.waker().clone());
            Poll::Pending
        }
    }
}
```

Les **futures** Rust sont assez bas niveau, le langage fournit le contrat : le trait ; charge à nous de l'implémenter. Du coup, quelques autres concepts sont nécessaires à appréhender comme les [Waker](https://rust-lang.github.io/async-book/02_execution/03_wakeups.html) et le [Pinning](https://rust-lang.github.io/async-book/04_pinning/01_chapter.html).

Il nous faut également écrire un [Executor](https://rust-lang.github.io/async-book/02_execution/05_io.html) qui va `poll` notre future jusqu'à l'atteinte d'une valeur de type `Poll::Ready<Output>` et les combinateurs `and_then`, `map_err` ou autres dont nous pourrions avoir besoin. La crate [futures](https://rust-lang-nursery.github.io/futures-api-docs/0.3.0-alpha.18/futures/) qui a servi d'incubateur aux **Futures** fournit des modules qui peuvent faciliter la tâche. Néanmoins écrire un **Executor** est une tâche fastidieuse et complexe. Heureusement pour nous, il existe [Tokio](https://tokio.rs) !

# Troisième version : futures ❤ Tokio

Tokio est une plate-forme de gestion d'I/O non bloquante, gérée par événement, permettant d'écrire des applications asynchrones avec Rust. À un niveau élevé, il fournit quelques composants majeurs:

- Un planificateur de tâches multithreadées -> _similaire à la notion d'Executor vue précédement_
- Un **Reactor**, adossé à la file d’événements du système d’exploitation (epoll, kqueue, IOCP, etc…) -> _un Executor reactif ... dans d'autre système on l'appelerait Event Loop_
- Des sockets TCP et UDP asynchrones

Au moment où j'écris cet artucle, le trait **Future** de Tokio, issu de la crate `futures` en version 0.1.x, est quelque peut différent de celui de la lib standard.
La version 0.3.0 de la crates Futures, actuellement en alpha, va s'aligner sur std::future::Future. Cependant il est aisé de passer de l'un à l'autre :

```rust
// futures::future::Future (0.1.x)
trait Future {
    type Item;
    type Error;

    fn poll(&mut self) -> Result<Async<Self::Item>, Self::Error>;
}
enum Async<T> {
    Ready(T),
    NotReady,
}
```

```rust
// std::future::Future & futures::future::Future (0.3.x)
trait Future {
    type Output;

    fn poll(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Self::Output>;
}

enum Poll<T> {
    Ready(T),
    Pending,
}
```

Tokio fournit aussi également le Trait **Stream**. Les Streams sont similaires aux Futures mais au lieu de retourner une unique valeur, ils donnent une ou plusieurs valeur de manière asynchrone.

```rust
trait Stream {
    type Item;
    type Error;

    fn poll(&mut self) -> Poll<Option<Self::Item>, Self::Error>;
}
```

Les Streams représentent bien ce que nous voulons faire avec notre serveur sur port série !

L'implémentation des Streams pour un port série existe déjà, nous allons donc utiliser la crate [tokio-serial](https://github.com/berkowski/tokio-serial), il nous suffit de fournir un codec pour serialiser et déserialiser le contenu du port série.

```rust
extern crate bytes;
extern crate futures;
extern crate tokio;
extern crate tokio_serial;

use bytes::{BufMut, BytesMut};
use futures::{Future, Sink, Stream};
use std::{env, str};
use tokio::codec::{Decoder, Encoder};
const DEFAULT_TTY: &str = "/tmp/ttyS1";

#[derive(Clone, Debug, Eq, PartialEq, Ord, PartialOrd, Hash)]
struct LineCodec;

impl Decoder for LineCodec {
    type Item = String;
    type Error = std::io::Error;

    fn decode(&mut self, src: &mut BytesMut) -> Result<Option<Self::Item>, Self::Error> {
        let newline = src.as_ref().iter().position(|b| *b == b'\n');
        if let Some(n) = newline {
            let line = src.split_to(n);
            src.take(); // flush the buffer
            if let Ok(s) = str::from_utf8(line.as_ref()) {
                Ok(Some(s.to_string()))
            } else {
                Err(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    "Invalid String",
                ))
            }
        } else {
            Ok(None)
        }
    }
}

impl Encoder for LineCodec {
    type Item = String;
    type Error = std::io::Error;

    fn encode(&mut self, item: Self::Item, dst: &mut BytesMut) -> Result<(), Self::Error> {
        println!("In writer {:?}", &item);
        dst.reserve(item.len() + 1);
        dst.put(item);
        dst.put_u8(b'\n');
        Ok(())
    }
}

fn main() {
    let mut args = env::args();
    let tty_path = args.nth(1).unwrap_or_else(|| DEFAULT_TTY.into());

    let settings = tokio_serial::SerialPortSettings::default();
    //tokio_serial::Serial implements tokio::prelude::AsyncRead, tokio::prelude::AsyncWrite
    let mut port = tokio_serial::Serial::from_path(tty_path, &settings).unwrap();
    if let Err(e) = port.set_exclusive(false) {
        eprintln!("Unable to set serial port exlusive{}", e)
    };
    // provide a tokio::codec::Framed and split it into a Sink and a Stream
    let (mut writer, reader) = LineCodec.framed(port).split();
    let echo_server = reader
        .for_each(move |line| {
            // wait block the current thread until the future is resolved (similar with await from std)
            let _ = (&mut writer).send(line).wait();
            Ok(())
        })
        .map_err(|e| eprintln!("{}", e));
    // start the tokio runtime that will poll our future
    tokio::run(echo_server);
}
```

Nous arrivons grâce aux futures à une version plus déclarative du code et surement plus facile à maintenir.
Les crates **Tokio** et **futures** nous fournissent les outils pour gérer relativement simplement nos _Futures_ ce qui est appréciable. Nous l'avons peu abordé mais le fait que Tokio fournissent également des impléméntations génériques pour les [adapteurs de Streams](https://tokio.rs/docs/futures/streams/#adapters) (for_earch, fold, or_else, take, filter, ...) et pour les [Futures](https://tokio.rs/docs/futures/combinators/#adapters) (map, map_err, then, join, select, ...) nous facilite le travail.

# Conclusion

Au final, nous sommes dans une période charnière car du côté de la librairie standard Rust la définition des `Futures` et de `async/await` se stabilisent seulement, ce qui demande un travail de boilerplate important pour créer ses propres futures et leur exécuteur, de l'autre nous avons avec `Tokio` et `futures` un environnement fonctionnel qui nous permet de nous concentrer sur nos applications. La convergence est en cours, mais il faut laisser le temps à la chronologie de se dérouler (futures est en train de s'aligner, puis se sera Tokio et les projets basé sur Tokio). Malgré cela l'usage de Tokio est un tel "game changer" que je l'utiliserai dès à présent pour mes nouveaux besoins, notamment l'évolution de notre librairie sur socket.

_Ce billet a été écrit au fur et à mesure de mes notes d'exploration, j'espère qu'il vous permettra de gagner du temps si vous vous avanturez sur le terrain des Futures Rust._
