# L'architecture Rust « parfaite » — guide de référence

> Document de référence pour scaffolder et faire évoluer un projet Rust
> production-grade. Cible primaire : **service backend async I/O-bound**
> (variantes lib/CLI/embedded signalées au fil du texte).
> Édition **2024**, écosystème mi-2026. Toolchain ≥ 1.85.
>
> Principe directeur : **le compilateur est ton meilleur reviewer.** Pousse
> les invariants dans le système de types ; ce qui ne compile pas ne peut
> pas casser en prod. Tout le reste en découle.
>
> ⚠️ Ce doc a un parti-pris. Chaque règle forte porte son *pourquoi* et,
> quand le choix est un trade-off réel, les deux écoles sont données — pas
> une prescription déguisée.

---

## 0. TL;DR — les 12 règles, avec leur statut

| # | Règle | Statut |
|---|---|---|
| 1 | Workspace multi-crates **quand la frontière mérite d'être imposée par le compilateur**, pas par défaut. | Nuancé (§1.3) |
| 2 | Hexagonal : ports = `trait`, adapters = `impl`. Le domaine ne connaît ni DB ni HTTP. | Fort |
| 3 | `thiserror` en lib, `anyhow` aux frontières (bin). Jamais `anyhow` dans une lib réutilisable. | Fort |
| 4 | Zéro `unwrap`/`expect`/`panic` en code prod, hors invariants documentés. | Fort |
| 5 | Newtypes pour tout primitif porteur de sémantique (`UserId`, `Email`). | Fort |
| 6 | « Parse, don't validate » : valide une fois à la frontière, propage le type-preuve. | Fort |
| 7 | Lints stricts dès le jour 1 : clippy `-D warnings`, `fmt --check` en CI. | Fort |
| 8 | `async` **seulement si I/O-bound à forte cardinalité**. CPU → threads/rayon. | Fort |
| 9 | `tracing` (spans structurés), jamais `println!`/`log` brut. **Pas de PII en clair.** | Fort |
| 10 | Tests d'intégration dans `tests/` contre l'API publique ; `cargo-nextest` en CI. | Fort |
| 11 | Convention « fichier nommé » (`foo.rs` + `foo/`), pas de `mod.rs`. | Convention |
| 12 | Config typée et validée au démarrage (`figment`/`config-rs`). | Fort |

Trois choix **délibérément non prescrits** car ce sont de vrais arbitrages :
`panic = abort|unwind` (§9.2), `static vs dyn dispatch` (§5.4),
`Cargo.lock` commité ou non (§8.3). Ils sont traités comme des décisions, pas des dogmes.

---

## 1. Structure du workspace

### 1.1 Layout cible

```
myproject/
├── Cargo.toml              # workspace root : [workspace], deps + lints partagés
├── Cargo.lock              # COMMITÉ par défaut (cf. §8.3)
├── rust-toolchain.toml     # pin toolchain (reproductibilité)
├── rustfmt.toml
├── clippy.toml
├── deny.toml               # cargo-deny : licences, advisories, bans
├── .config/nextest.toml
├── .sqlx/                  # query cache offline sqlx (commité, cf. §8.4)
├── CLAUDE.md               # règles d'archi + nommage du projet
├── crates/
│   ├── domain/             # logique métier PURE — zéro dép infra/runtime
│   │   └── src/{lib.rs, model/, ports/, service/}
│   ├── infra/              # adapters : impls concrètes des ports
│   │   └── src/{lib.rs, postgres/, http_client/, config.rs}
│   └── app/                # entrypoint (bin) : wiring + transport
│       └── src/{main.rs, http/, telemetry.rs}
└── xtask/                  # (optionnel) automation interne en Rust
```

### 1.2 Sens des dépendances (la règle d'or)

```
app  ──────►  domain  ◄──────  infra
 │                                ▲
 └────────────────────────────────┘
        app câble les adapters d'infra dans les ports du domain
```

- `domain` ne dépend de **personne** : ni `infra`, ni `app`, ni `tokio`, ni `sqlx`. Idéalement même pas de `serde` (garde la sérialisation dans une couche DTO). Exception pragmatique tolérée : `uuid`, `time`/`chrono` — des types de valeur, pas du runtime.
- `infra` dépend de `domain` (il *implémente* ses traits).
- `app` dépend des deux : **composition root** qui instancie le concret et l'injecte.
- La dépendance pointe toujours **vers l'intérieur** (le domaine). C'est ce qui rend le métier testable sans I/O et permet de swap un adapter sans toucher au métier.

> **Pour un dev Go** : équivalent de définir les `interface` côté *consommateur*
> (le package métier) et les impls dans des packages séparés câblés dans `main`.
> Différence : ici le **graphe de crates** rend l'import croisé physiquement
> impossible — c'est vérifié par le compilateur, pas par la discipline.

### 1.3 Quand NE PAS faire de multi-crates *(challenge de la v1)*

Le multi-crates a un coût réel : friction, plus de `Cargo.toml`, refactors cross-crate plus lourds. Le bénéfice n'est **pas** la « propreté » — c'est :
1. **forcer** la frontière de dépendances par le compilateur (impossible d'importer `infra` depuis `domain`) ;
2. **paralléliser/cacher** la compilation (les crates compilent indépendamment) ;
3. publier la lib séparément.

Si tu ne veux aucun des trois : **un seul crate, des modules** (`mod domain`, `mod infra`, `mod app`). La frontière tient alors par convention + revue. Commence là, éclate en crates quand un de ces trois besoins devient concret. La sur-ingénierie d'archi coûte aussi cher que son absence.

### 1.4 `Cargo.toml` workspace — deps & lints centralisés

```toml
[workspace]
resolver = "3"                 # resolver de l'edition 2024
members  = ["crates/*", "xtask"]

[workspace.package]
edition = "2024"
rust-version = "1.85"          # MSRV : testé en CI (cf. §8.5)
license = "MIT OR Apache-2.0"

[workspace.dependencies]       # versions définies UNE fois, héritées par les crates
tokio     = { version = "1", features = ["rt-multi-thread", "macros"] }
axum      = "0.8"
sqlx      = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid"] }
thiserror = "2"
anyhow    = "1"
tracing   = "0.1"
serde     = { version = "1", features = ["derive"] }
uuid      = { version = "1", features = ["v4", "serde"] }

[workspace.lints.rust]
# 'forbid' = INTERDIT et NON-OVERRIDABLE (un #[allow] local échoue à compiler).
# Si tu prévois de lever unsafe dans un crate (FFI, perf), mets 'deny' à la place.
unsafe_code = "forbid"
missing_docs = "deny"          # toute API publique documentée (le POURQUOI)
missing_debug_implementations = "warn"
unreachable_pub = "warn"       # détecte le pub qui ne sort jamais du crate

[workspace.lints.clippy]
all      = { level = "deny",  priority = -1 }
pedantic = { level = "warn",  priority = -1 }   # bruyant : voir §8.2 avant de l'activer partout
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"                 # la règle « zéro panic » est ENFORCÉE, pas déclarée
todo = "deny"
unimplemented = "deny"
dbg_macro = "deny"             # debug oublié
print_stdout = "deny"          # les sorties passent par `tracing`
print_stderr = "deny"
mod_module_files = "deny"      # impose foo.rs (interdit mod.rs)
```

Le pendant côté `clippy.toml` : `allow-unwrap-in-tests`, `allow-expect-in-tests`,
`allow-panic-in-tests`, `allow-print-in-tests`, `allow-dbg-in-tests` — les tests
gardent le droit de panic/print, la prod jamais.

Chaque crate hérite ensuite via `tokio.workspace = true` et `[lints] workspace = true`.

> **Correctif v1** : `forbid` ne peut PAS être levé par `#[allow]` — c'est tout
> l'intérêt du niveau. La v1 prétendait le contraire. Choisis `deny` si tu veux
> garder la porte de sortie.

---

## 2. Architecture hexagonale — le code réel (compile)

### 2.1 Domaine : modèle + newtypes

```rust
// crates/domain/src/model/user.rs
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(Uuid);

impl UserId {
    pub fn new() -> Self { Self(Uuid::new_v4()) }
    pub fn from_uuid(id: Uuid) -> Self { Self(id) }   // ← manquait en v1, cassait l'adapter
    pub fn as_uuid(&self) -> Uuid { self.0 }
}

impl Default for UserId {
    fn default() -> Self { Self::new() }              // clippy::new_without_default
}

/// "Parse, don't validate" : un Email ne PEUT exister que valide.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Email(String);

impl Email {
    pub fn parse(raw: impl Into<String>) -> Result<Self, EmailError> {
        let raw = raw.into();
        // (validation illustrative — en vrai, valide selon ton besoin métier)
        if raw.contains('@') && raw.len() <= 254 {
            Ok(Self(raw))
        } else {
            Err(EmailError::Invalid)
        }
    }
    pub fn as_str(&self) -> &str { &self.0 }
}

#[derive(Debug, thiserror::Error)]
#[non_exhaustive]                                     // cf. §3.4
pub enum EmailError {
    #[error("adresse email invalide")]
    Invalid,
}

#[derive(Debug, Clone)]
pub struct User { pub id: UserId, pub email: Email }
```

Passé `Email::parse`, **aucune fonction ne revérifie** : le type est la preuve. C'est l'idiome qui élimine des classes entières de bugs « j'ai oublié de valider ici ».

### 2.2 Port (trait) — et le piège `Send`

```rust
// crates/domain/src/ports/user_repository.rs
use crate::model::{User, UserId};

/// Port : le domaine déclare CE dont il a besoin, pas COMMENT.
/// async fn en trait est stable (1.75+). MAIS : le future retourné n'est PAS
/// garanti `Send`. Pour un repo partagé entre tâches `tokio::spawn` sur un
/// runtime multi-thread, il FAUT du Send. Trois options :
///   1. rester en générique statique `<R: UserRepository>` (cf. §2.3) — le
///      future concret est Send si l'impl l'est. Zéro coût. Préféré.
///   2. `#[trait_variant::make(UserRepository: Send)]` pour générer une variante Send.
///   3. l'historique `#[async_trait]` (boxe le future ; coût runtime, mais dyn-safe).
pub trait UserRepository: Send + Sync {
    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError>;
    async fn save(&self, user: &User) -> Result<(), RepoError>;
}

#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RepoError {
    #[error("entité absente")]
    NotFound,
    #[error("erreur de stockage")]
    Backend(#[source] Box<dyn std::error::Error + Send + Sync>),
}
```

### 2.3 Use case — testable sans I/O, dispatch statique

```rust
// crates/domain/src/service/register_user.rs
use crate::model::{Email, User, UserId};
use crate::ports::{RepoError, UserRepository};

pub struct RegisterUser<R: UserRepository> { repo: R }

impl<R: UserRepository> RegisterUser<R> {
    pub fn new(repo: R) -> Self { Self { repo } }

    pub async fn execute(&self, email: Email) -> Result<UserId, RegisterError> {
        let user = User { id: UserId::new(), email };
        self.repo.save(&user).await?;
        Ok(user.id)
    }
}

#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RegisterError {
    #[error(transparent)]
    Repo(#[from] RepoError),
}
```

Le générique `<R>` est **monomorphisé** : pas de boxing, le future est Send si `R` l'est, le compilateur inline. C'est le défaut à préférer (§5.4 pour le trade-off avec `dyn`).

### 2.4 Adapter (infra)

```rust
// crates/infra/src/postgres/user_repo.rs
use domain::model::{Email, User, UserId};
use domain::ports::{RepoError, UserRepository};
use sqlx::PgPool;

pub struct PgUserRepository { pool: PgPool }

impl PgUserRepository {
    pub fn new(pool: PgPool) -> Self { Self { pool } }
}

impl UserRepository for PgUserRepository {
    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
        let row = sqlx::query!("SELECT id, email FROM users WHERE id = $1", id.as_uuid())
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| RepoError::Backend(Box::new(e)))?;

        row.map(|r| {
            Ok(User {
                id: UserId::from_uuid(r.id),
                email: Email::parse(r.email)
                    .map_err(|e| RepoError::Backend(Box::new(e)))?,
            })
        })
        .transpose()
    }

    async fn save(&self, user: &User) -> Result<(), RepoError> {
        sqlx::query!(
            "INSERT INTO users (id, email) VALUES ($1, $2)",
            user.id.as_uuid(),
            user.email.as_str(),
        )
        .execute(&self.pool)
        .await
        .map_err(|e| RepoError::Backend(Box::new(e)))?;
        Ok(())
    }
}
```

> `sqlx::query!` est **vérifié à la compilation** contre une vraie DB → nécessite
> soit `DATABASE_URL`, soit le cache offline `.sqlx/` (§8.4). Sans ça, ta CI casse.

### 2.5 Composition root (app)

```rust
// crates/app/src/main.rs
use anyhow::Context;                      // anyhow ICI, jamais dans domain/infra
use domain::service::RegisterUser;
use infra::postgres::PgUserRepository;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cfg = app::config::load().context("chargement config")?;
    app::telemetry::init(&cfg.telemetry)?;

    let pool = infra::postgres::connect(&cfg.database).await.context("connexion postgres")?;
    let register = RegisterUser::new(PgUserRepository::new(pool));   // injection

    app::http::serve(cfg.http, register).await?;
    Ok(())
}
```

**C'est ici, et seulement ici, que le concret rencontre l'abstrait.** Le domaine ignore que Postgres existe ; tu remplaces l'adapter par un `InMemoryUserRepository` en test sans toucher au métier.

---

## 3. Gestion d'erreurs

### 3.1 La règle

| Contexte | Outil | Pourquoi |
|---|---|---|
| Lib / crate réutilisable | `thiserror` | Le caller doit pouvoir **matcher** les variantes et les traiter. |
| Bin / `main` / frontière | `anyhow` | On veut message + chaîne de contexte ; le type exact est égal. |
| Jamais en prod | `unwrap`/`expect`/`panic` | Crash non récupérable. Tests + invariants documentés uniquement. |

### 3.2 Design des variantes

- **Ne pas exploser le nombre de variantes.** 20 variantes toutes traitées pareil = sur-ingénierie. Une variante existe pour qu'un caller la traite *différemment*. Sinon, regroupe ou `#[error(transparent)]`.
- **Toujours préserver la chaîne** : `#[source]` ou `#[from]`. Perdre la cause racine = debug à l'aveugle.
- **Aux frontières d'app**, ajoute du contexte : `.context("ce que je tentais")` transforme un `connection refused` cryptique en `connexion postgres: connection refused`.

```rust
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum OrderError {
    #[error("stock insuffisant pour {sku}")]
    OutOfStock { sku: String },
    #[error("paiement refusé")]
    PaymentDeclined(#[source] PaymentError),
    #[error(transparent)]
    Repo(#[from] RepoError),
}
```

### 3.3 Panics : la liste blanche

`panic!`/`unwrap`/`expect` acceptables uniquement si :
- c'est un **test** ;
- c'est un **invariant que le compilateur ne voit pas**, documenté : `// INVARIANT: slice non vide, garanti par la validation L42`. Préfère `.expect("raison")` à `.unwrap()` — le message explique l'invariant ;
- c'est le **démarrage** (config absente → crash clair et immédiat vaut mieux qu'un état dégradé).

CI : `clippy::unwrap_used = "deny"` force la discipline.

### 3.4 `#[non_exhaustive]` sur les erreurs publiques *(ajout v2)*

Sur toute enum d'erreur exposée par une lib, mets `#[non_exhaustive]`. Ça **interdit aux callers le `match` exhaustif sans bras `_`** → tu peux ajouter une variante plus tard **sans casser leur build** (pas de bump major). Sans ça, chaque nouvelle variante est un breaking change SemVer. Coût côté caller : un `_ => …` obligatoire. Sur un type purement interne (`pub(crate)`), inutile.

---

## 4. Async : quand, comment, pièges

### 4.1 La décision async vs sync

**`async` n'est pas « plus rapide ». C'est de la concurrence I/O-bound à forte cardinalité** (milliers de connexions/tâches en vol). Selon ton profil :
- **CPU-bound** → threads natifs / `rayon`. L'async n'apporte rien et ajoute de la complexité (couleur de fonction, `Pin`, lifetimes de futures).
- **I/O-bound, peu de tâches** → du sync threadé suffit souvent et se debug mieux.
- **I/O-bound, forte concurrence** → async + `tokio`.

`tokio` est le runtime de facto (écosystème axum/sqlx/reqwest aligné). Ne mélange pas deux runtimes dans un même process.

### 4.2 Les pièges qui tuent en prod

1. **Bloquer l'executor.** Scheduling coopératif : une tâche ne yield qu'au `.await`. Du CPU lourd ou un appel sync bloquant entre deux `.await` **gèle un worker thread entier**. → `tokio::task::spawn_blocking` ou pool dédié.
2. **`std::sync::Mutex` tenu à travers un `.await`** → risque de deadlock + non-Send. Règle : garde `std::sync::Mutex` et **relâche-le avant l'`.await`** (plus rapide). N'utilise `tokio::sync::Mutex` *que* si tu dois vraiment tenir le lock à travers un await.
3. **Cancellation = `Drop`.** Annuler un future = le drop. Tout cleanup passe par `Drop`, et un future peut être abandonné à n'importe quel point d'await → attention aux **états partiels** (cancel-safety). Un `select!` qui drop une branche à moitié écrite est un bug classique.
4. **Backpressure des channels.** Buffer trop grand = mémoire qui explose, latence masquée. Commence petit (`mpsc::channel(32)`), augmente sous mesure.
5. **`async fn` qui n'await jamais** = pur overhead. Ne rends pas async ce qui est calculatoire.

### 4.3 Squelette runtime

```rust
#[tokio::main]                       // multi-thread par défaut
async fn main() -> anyhow::Result<()> { /* ... */ }

// Variante contrôlée — available_parallelism() est en std (pas de crate num_cpus) :
fn main() -> anyhow::Result<()> {
    let workers = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(1);
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(workers)
        .enable_all()
        .build()?
        .block_on(run())
}
```

---

## 5. Idiomes, clean code, dispatch

### 5.1 Patterns à coût zéro

- **Newtype** (`UserId(Uuid)`) : type safety, impossible de mélanger deux ids. Aucun overhead mémoire/runtime (effacé à la compilation).
- **Typestate** : encode l'état dans le type. Transitions invalides = **erreur de compilation**, zéro check runtime.

  ```rust
  use std::marker::PhantomData;        // ← manquait en v1

  struct Open;
  struct InTransaction;

  struct Connection<State> { /* champs réels */ _state: PhantomData<State> }

  impl Connection<Open> {
      fn begin(self) -> Connection<InTransaction> { /* consomme self */ todo!() }
  }
  impl Connection<InTransaction> {
      fn commit(self) -> Connection<Open> { todo!() }   // self consommé : pas de double-commit
  }
  ```

- **Builder** pour beaucoup de params optionnels (`bon`, `derive_builder`).
- **`From`/`TryFrom`** pour les conversions, jamais des `to_x` ad hoc.
- **`impl Trait`** en argument (`impl Into<String>`) et retour (`impl Iterator<Item=…>`) : ergonomie sans boxing.

### 5.2 Règles de clean code spécifiques Rust

- **Rends les états invalides irreprésentables.** Pas `struct { is_active: bool, deactivated_at: Option<…> }` (combinaisons incohérentes), mais `enum Status { Active, Inactive { since: DateTime } }`.
- **Emprunte en argument** : `&str` > `String`, `&[T]` > `Vec<T>`. Le caller décide d'allouer ou non.
- **Itérateurs > boucles indexées** : pas d'off-by-one, souvent aussi rapide, plus lisible.
- **`?` partout** pour propager ; pas de `match` verbeux sur `Result`.
- **`#[must_use]`** sur les types/fns dont ignorer le retour est un bug.
- **Visibilité minimale** : `pub(crate)` par défaut, `pub` seulement l'API contractuelle. Lint `unreachable_pub` pour traquer le faux-`pub`.
- **Doc `///`** sur l'API publique, avec exemples (les doctests sont compilés ET exécutés).
- **`clone()` réflexe = signal.** Une `clone()` justifiée est fine ; une `clone()` pour faire taire le borrow checker cache un problème de design.

### 5.3 Organisation des modules

- **Convention « fichier nommé »** : `foo.rs` + dossier `foo/`. **Pas de `mod.rs`** (`clippy::mod_module_files`). Évite 15 onglets `mod.rs`.
- Expose l'API via `pub use` (re-exports) → découple structure interne et surface publique.
- Pas de modules fourre-tout (`utils`, `helpers`, `common`) : range par domaine fonctionnel.

### 5.4 Static vs dynamic dispatch — le vrai trade-off *(ajout v2)*

| | Générique `<R: Trait>` (static) | `Box<dyn Trait>` / `&dyn Trait` (dynamic) |
|---|---|---|
| Coût appel | nul (inliné, monomorphisé) | indirection vtable |
| Taille binaire / compile | gonfle (une copie par type) | compact |
| Send des futures async | OK naturellement | nécessite `async-trait`/`trait_variant` |
| Flexibilité runtime | figé à la compilation | collections hétérogènes, plugins, choix au runtime |

**Heuristique** : par défaut **static** (perf, zéro coût, Send gratuit). Passe à `dyn` quand tu en as un *besoin concret* : stocker des impls hétérogènes dans un `Vec<Box<dyn …>>`, choisir l'impl au runtime, ou couper une explosion de monomorphisation qui plombe les temps de compile. Ne « boxe » pas par réflexe OO.

---

## 6. Observabilité

### 6.1 `tracing`, pas `log` — et pas de PII

`tracing` apporte les **spans** (opérations dans le temps, indispensables en async où le flux n'est pas linéaire) + champs structurés.

```rust
use tracing::{info, instrument};

// On logge l'ID (non-PII), PAS l'email. Voir l'avertissement ci-dessous.
#[instrument(skip(repo, email), fields(user.id = %id))]
async fn register(repo: &impl UserRepository, id: UserId, email: Email)
    -> Result<UserId, RegisterError>
{
    info!("création utilisateur");
    // le span "register" enveloppe tout, y compris à travers les .await
    todo!()
}
```

> **⚠️ PII / RGPD.** Ne mets jamais d'email, nom, IP, token en clair dans les
> champs de span ou les logs — ils partent en clair vers ton backend de logs et
> y restent. La v1 loggait `user.email` : erreur. Logge un identifiant opaque,
> ou hashe/tronque si tu as besoin de corréler. `#[instrument]` capture les
> arguments par défaut → `skip(...)` tout ce qui est sensible.

### 6.2 Setup

```rust
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

pub fn init() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .with(tracing_subscriber::fmt::layer().json())   // logs JSON structurés en prod
        .init();
    Ok(())
}
```

- **Prod** : sortie JSON → Loki/ELK/OpenObserve.
- **Distribué** : `tracing-opentelemetry` → spans/métriques vers Jaeger/Prometheus/OTLP, corrélation logs↔traces↔métriques.
- **Jamais** `println!`/`dbg!` en code livré (`dbg!` = debug local éphémère, et il écrit sur stderr sans structure).

---

## 7. Tests

### 7.1 Pyramide

- **Unitaires** : dans le module, `#[cfg(test)] mod tests`. Accès au privé. La logique pure du domaine brille ici (pas de DB, pas de mock lourd).
- **Intégration** : `tests/` à la racine du crate. Voient **uniquement l'API publique** → valident le contrat réel.
- **Doctests** : exemples `///` compilés et exécutés. Double rôle doc + non-régression d'API.

### 7.2 Mock du domaine = juste un autre adapter

Pas de framework de mock pour le métier : implémente le port en mémoire.

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    #[derive(Default)]
    struct InMemoryRepo { users: Mutex<Vec<User>> }

    impl UserRepository for InMemoryRepo {
        async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
            // lock pris et relâché AVANT tout await (cf. §4.2 piège 2)
            let found = self.users.lock().unwrap().iter().find(|u| u.id == id).cloned();
            Ok(found)
        }
        async fn save(&self, user: &User) -> Result<(), RepoError> {
            self.users.lock().unwrap().push(user.clone());
            Ok(())
        }
    }

    #[tokio::test]
    async fn register_persists_user() {
        let repo = InMemoryRepo::default();
        let svc = RegisterUser::new(repo);
        let email = Email::parse("a@b.com").unwrap();   // unwrap OK : c'est un test
        let id = svc.execute(email).await.unwrap();
        assert!(svc.repo.find(id).await.unwrap().is_some());
    }
}
```

### 7.3 Outillage

- **`cargo-nextest`** : runner plus rapide, meilleure isolation par test, sortie CI lisible. (Ne lance **pas** les doctests → garde `cargo test --doc` à côté.)
- **`proptest`/`quickcheck`** : property-based pour les invariants (`parse ∘ format == identité`).
- **`testcontainers`** : vraie Postgres/Redis jetable en intégration. **Ne mocke pas la DB** si tu peux tester contre une instance éphémère — les mocks divergent du réel et masquent les bugs de SQL/migration.
- **`criterion`** : benchmarks statistiques (pour le code perf-critique).

---

## 8. Tooling, lints, CI

### 8.1 Config toolchain

```toml
# rust-toolchain.toml
[toolchain]
channel = "1.85"
components = ["rustfmt", "clippy"]
```

### 8.2 Clippy strict — avec une nuance sur `pedantic` *(challenge v1)*

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

`clippy::all` en **deny** : non négociable. `clippy::pedantic` : **utile mais bruyant** — il flag des choses légitimes (`must_use_candidate`, `module_name_repetitions`…). Recommandation honnête : active-le en **`warn`**, traite ce qui a du sens, et le reste en `#[expect(clippy::xxx, reason = "…")]` ciblé — `#[expect]` plutôt
que `#[allow]` : il **avertit quand il ne sert plus** (lint auto-nettoyant) et la
`reason` est obligatoire de fait. Ne le mets pas en `deny` global sauf équipe disciplinée — sinon tu passeras ton temps à le museler. Groupes à privilégier sans réserve : `correctness`, `suspicious`, `perf`.

### 8.3 `Cargo.lock` : commiter ou non *(corrigé — sagesse renversée en 2023)*

L'ancienne règle (« commit pour bin, ignore pour lib ») est **abandonnée par la Cargo team depuis août 2023**. Recommandation actuelle :
- **Commite `Cargo.lock` par défaut, dans tous les cas — lib comprise.** C'est le point de départ.
- Raison : permet de **valider ton MSRV** et d'avoir des builds CI reproductibles ; combiné à Dependabot/Renovate, tu testes quand même les montées de version. Avant, les auteurs de libs mettaient des upper-bounds de version (pire solution) à cause de l'ancienne règle.
- Tu peux déroger (ne pas commiter) si tu as une vraie raison, mais ce n'est plus le défaut. ([Rust Blog, 2023-08-29](https://blog.rust-lang.org/2023/08/29/committing-lockfiles/))

### 8.4 sqlx en CI — mode offline *(ajout v2)*

`sqlx::query!` vérifie tes requêtes **à la compilation** contre une vraie DB. Pour que la CI compile sans `DATABASE_URL` :

```bash
cargo sqlx prepare        # génère/maj le cache .sqlx/ depuis une DB locale
git add .sqlx             # commité → la CI compile en mode offline
```

Sinon : `error: set DATABASE_URL to use query macros` au build CI. Alternative : `query` (non vérifié) si tu acceptes de perdre le check compile-time.

### 8.5 Pipeline CI

```bash
cargo fmt --all -- --check                          # formatage non négociable
cargo clippy --all-targets --all-features -- -D warnings
cargo nextest run --all-features                    # tests
cargo test --doc                                    # doctests (nextest ne les lance pas)
cargo deny check                                    # licences + advisories sécu + bans + doublons
cargo +1.85 check --workspace                       # garde-fou MSRV (cf. rust-version)
```

- **`cargo-deny`** : refuse une dép avec CVE connue (RustSec), licence interdite, version dupliquée.
- **MSRV** : si tu annonces `rust-version`, teste-le — sinon il dérive en silence.

---

## 9. Performance & profil de build

### 9.1 Mesure d'abord

`criterion` pour les benchs ; `cargo flamegraph`/`perf` pour le CPU ; **`tokio-console`** pour voir tes tâches async (tâches bloquées, famine). N'optimise **jamais** sans profil.

### 9.2 Profil release — et le débat `panic` *(challenge v1)*

```toml
[profile.release]
lto = "thin"            # link-time optimization (bon ratio gain/temps)
codegen-units = 1       # +lent à compiler, +rapide à l'exécution
strip = true
# panic = "abort"       # ← DÉCISION, pas un défaut. Lis ci-dessous.
```

**`panic = "abort"` vs `"unwind"` (défaut) — vrai arbitrage, surtout pour un serveur :**

- **`unwind` (défaut)** : tokio **catch** la panic d'une tâche `spawn` ; un handler HTTP qui panic ne tue **que sa requête**, le serveur survit. Avantage dispo. Risque : continuer à tourner avec un état potentiellement incohérent post-panic.
- **`abort`** : toute panic tue le process. Binaire plus petit, pas de machinerie d'unwinding, **fail-fast** (un superviseur — k8s, systemd — redémarre proprement). École « une panic = un bug = je veux crasher et repartir d'un état sain ». Mais une panic isolée dans une requête tue tout le serveur.

**Reco nuancée** : serveur derrière un orchestrateur qui redémarre vite + tu veux fail-fast → `abort`. Serveur où la dispo par-requête prime → garde `unwind` + un panic hook qui log/alerte. Ne copie pas `abort` d'un blog sans décider. (Note : `abort` casse `#[should_panic]` et la capture de panic en test.)

### 9.3 Allocations & zero-copy

- `Vec::with_capacity` quand tu connais la taille ; évite les `collect()` intermédiaires inutiles.
- `&str`/`&[T]` en API : pas d'allocation forcée chez le caller.
- `rayon` (`.par_iter()`) pour le CPU-bound data-parallel : trivial, très efficace.
- `bytes::Bytes`, `Cow<str>` pour le zero-copy quand la donnée est tantôt empruntée tantôt possédée.
- Les abstractions Rust (newtype, traits génériques, itérateurs, `impl Trait`) sont **zero-cost** : abstrais pour la lisibilité, ça ne coûte rien à l'exécution. Le `dyn` (§5.4) est la seule abstraction à coût runtime.

---

## 10. Feature flags Cargo *(section ajoutée v2)*

Ton CLAUDE.md exige des « feature flags propres ». La règle d'or, souvent ignorée :

**Les features doivent être ADDITIVES.** Activer une feature ne doit jamais *retirer* ou *changer* du comportement — seulement en ajouter. Pourquoi : Cargo **unifie** les features à travers tout le graphe de dépendances. Si le crate A active `foo` et le crate B ne l'active pas, ta lib est compilée **avec** `foo` pour les deux. Une feature qui désactive du code (`#[cfg(not(feature = "x"))]` qui change la sémantique) casse silencieusement B.

```toml
[features]
default = ["postgres"]                 # le strict nécessaire au démarrage immédiat
postgres = ["dep:sqlx"]                # dep:  = dépendance optionnelle, pas réexportée comme feature
metrics  = ["dep:prometheus"]
full     = ["postgres", "metrics"]     # agrégat pratique
```

Conventions :
- Pas de features **mutuellement exclusives** (`runtime-tokio` vs `runtime-async-std` est un anti-pattern qui mord à l'unification). Si tu dois, documente-le très fort.
- `default` minimal : le caller retire difficilement une default feature (`default-features = false` est tout-ou-rien).
- `dep:nom` pour une dépendance optionnelle qui ne doit pas devenir une feature publique implicite.
- Teste `--no-default-features` et `--all-features` en CI : c'est là que les `#[cfg]` cassés se révèlent.

---

## 11. Checklist de revue (à coller en PR)

- [ ] Le domaine ne dépend d'aucune crate d'infra/runtime (vérifiable dans `Cargo.toml`).
- [ ] Aucun `unwrap`/`expect`/`panic` hors tests et invariants documentés.
- [ ] Erreurs : chaîne préservée (`#[source]`/`#[from]`), `thiserror` en lib / `anyhow` en bin, `#[non_exhaustive]` sur les enums publiques.
- [ ] Primitifs sémantiques = newtypes ; validation à la frontière (parse, don't validate).
- [ ] Pas de `std::Mutex` tenu à travers `.await` ; pas de blocage de l'executor ; cancel-safety vérifiée sur les `select!`.
- [ ] `tracing` (pas de `println!`) ; **aucune PII en clair** dans les spans/logs.
- [ ] Dispatch : static par défaut, `dyn` justifié par un besoin runtime concret.
- [ ] Tests : unitaires sur le domaine, intégration sur l'API publique, vraie DB jetable si SQL.
- [ ] `fmt --check` + `clippy -D warnings` + `cargo deny` passent ; cache `.sqlx` à jour si sqlx.
- [ ] Features additives ; `--no-default-features` et `--all-features` compilent.
- [ ] API publique minimale (`pub(crate)` par défaut) et documentée.
- [ ] États invalides irreprésentables (enums plutôt que bool + Option corrélés).

---

## 12. Variantes selon la cible

Ce doc vise un **service async**. Si ta cible diffère :

- **Lib pure** : pas de `tokio`/`async` imposé (expose du sync, laisse le caller choisir son runtime — ou propose les deux via features additives) ; `#[non_exhaustive]` et SemVer deviennent critiques ; pas d'`anyhow` exposé ; doctests = ta vraie doc.
- **CLI** : `clap` (derive) ; souvent sync suffit ; `anyhow` partout sauf si une partie est extraite en lib ; pense à `--json` pour la composabilité.
- **Embedded / `no_std`** : pas de `std`, pas d'alloc parfois ; `heapless`, `defmt` (pas `tracing`) ; erreurs sans `Box` ; tout ce qui touche au heap/async ci-dessus est à revoir.

---

## Sources

- [Change in Guidance on Committing Lockfiles — Rust Blog (2023)](https://blog.rust-lang.org/2023/08/29/committing-lockfiles/)
- [Master Hexagonal Architecture in Rust — howtocodeit](https://www.howtocodeit.com/guides/master-hexagonal-architecture-in-rust)
- [The best way to structure Rust web services — LogRocket](https://blog.logrocket.com/best-way-structure-rust-web-services/)
- [The State of Async Rust: Runtimes — corrode](https://corrode.dev/blog/async/)
- [Dealing with cancel safety in async Rust — Oxide RFD 400](https://rfd.shared.oxide.computer/rfd/0400)
- [Don't panic!() (panic abort vs unwind, serveurs) — 0xd.org](https://0xd.org/blog/2021-03-20_Dont-Panic.html)
- [Error Handling In Rust - A Deep Dive — Luca Palmieri](https://www.lpalmieri.com/posts/error-handling-rust/)
- [How to Design Error Types with thiserror and anyhow — OneUptime](https://oneuptime.com/blog/post/2026-01-25-error-types-thiserror-anyhow-rust/view)
- [idiomatic-rust (collection peer-reviewed) — mre/idiomatic-rust](https://github.com/mre/idiomatic-rust)
- [The Newtype and Type-State Patterns — Microsoft RustTraining](https://microsoft.github.io/RustTraining/rust-patterns-book/ch03-the-newtype-and-type-state-patterns.html)
- [Structured logging with tracing & OpenTelemetry — OneUptime](https://oneuptime.com/blog/post/2026-01-07-rust-tracing-structured-logs/view)
- [Faster Rust Tests With cargo-nextest — JetBrains](https://blog.jetbrains.com/rust/2026/05/01/faster-rust-tests-with-cargo-nextest/)
- [The Rust Performance Book — Linting / Profil](https://nnethercote.github.io/perf-book/linting.html)
- [Clippy Lints (référence) — rust-lang](https://rust-lang.github.io/rust-clippy/master/index.html)
- [Cargo features — The Cargo Book](https://doc.rust-lang.org/cargo/reference/features.html)
- [Modules — The Rust Reference](https://doc.rust-lang.org/reference/items/modules.html)
