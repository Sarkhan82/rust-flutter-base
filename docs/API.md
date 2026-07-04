# Contrat d'API HTTP — source de vérité

> Ce document décrit le contrat entre le backend Rust (`rust/`) et l'app
> Flutter (`app/`). **Le backend fait foi** ; toute modification de route ou de
> DTO se fait ici D'ABORD, puis dans le code des deux moitiés, dans le même PR
> ou en PRs coordonnés (backend d'abord).

## Conventions générales

- Préfixe : toutes les routes métier vivent sous **`/api/v1`**. Un breaking
  change de contrat ⇒ nouvelle version `/api/v2`, jamais de mutation silencieuse.
- Format : JSON (`Content-Type: application/json`), UTF-8.
- Nommage JSON : `snake_case`.
- Identifiants : UUID v4 sous forme de chaîne canonique.
- Chaque réponse porte un header **`x-request-id`** (corrélation des traces).
  Un client peut fournir le sien, il est propagé.

## Limites transverses (config serveur)

| Limite | Défaut | Dépassement |
|---|---|---|
| Taille du corps de requête | 2 Mio | `413 Payload Too Large` |
| Durée d'une requête | 30 s | `408 Request Timeout` |
| CORS | permissif en dev, origines explicites en prod | préflight refusé |

## Format d'erreur (uniforme)

Toute erreur applicative renvoie ce corps :

```json
{ "error": "<code_machine>", "message": "<phrase lisible>" }
```

| HTTP | `error` | Quand |
|---|---|---|
| 404 | `not_found` | Ressource inexistante |
| 422 | `validation` | Entrée syntaxiquement valide mais rejetée par le domaine |
| 500 | `internal` | Erreur interne — **jamais de détail technique dans `message`** |

Règle : ajouter un cas d'erreur = ajouter sa ligne ici + son mapping dans
`rust/crates/app/src/http/error.rs` + un test d'intégration.

## Endpoints

### `GET /health`

Sonde de liveness/readiness. Hors `/api/v1` (infra, non versionnée).

- `200 OK` → `{ "status": "ok" }`

### `GET /api/v1/greeting?name=<string>`

Feature témoin de bout en bout (consommée par la feature `greeting` Flutter).

- `name` optionnel ; absent/vide ⇒ salutation générique.
- `200 OK` → `{ "message": "Bonjour, Alice ! 👋" }`

### `GET /api/v1/users`

Liste les utilisateurs.

- `200 OK` → `[ { "id": "<uuid>", "email": "a@b.com" }, … ]`
- ⚠️ Témoin volontairement minimal : **non paginé**. Toute vraie collection
  doit être paginée dès sa création (cf. `rust/CLAUDE.md`, anti-patterns).

### `POST /api/v1/users`

Crée un utilisateur.

- Corps : `{ "email": "a@b.com" }`
- `201 Created` → `{ "id": "<uuid>", "email": "a@b.com" }`
- `422` (`validation`) si l'email est invalide.

### `GET /api/v1/users/{id}`

Récupère un utilisateur.

- `200 OK` → `{ "id": "<uuid>", "email": "a@b.com" }`
- `404` (`not_found`) si l'id est inconnu.

## Checklist « je change le contrat »

1. Mettre ce fichier à jour (route, DTO, erreurs, exemple).
2. Backend : DTO + handler + mapping d'erreur + test d'intégration (`rust/crates/app/tests/`).
3. Frontend : datasource + modèle + tests (`app/`), coordonné avec `flutter-architect`.
4. Breaking change ⇒ `/api/v(N+1)`, l'ancienne version reste servie le temps de la migration.
