# Spécification — Package R `duckR`

> **Statut : spec figée, validée.** Document de référence pour la phase de codage.
> Ce document décrit le *quoi* et le *comment* attendu ; il ne contient pas le code.

---

## 1. Objectif

Fournir une surcouche **légère** à DuckDB, qui maximise l'usage de **SQL** et du package **DBI**, pour :

- ouvrir une connexion DuckDB sobre en mémoire ;
- charger facilement des fichiers Parquet / CSV et des requêtes `dbplyr` (lazy) ;
- explorer et suivre l'état de la connexion ;
- attacher une base PostgreSQL externe ;
- offrir un retour visuel clair en console (succès / échec).

---

## 2. Décisions validées (récapitulatif)

| Sujet | Décision |
|---|---|
| Connexion par défaut | Environnement interne au package stockant la connexion « courante » (pas de variable globale `conDB`). |
| Nommage des fonctions | `snake_case`, préfixe `duckr_`. |
| Plafond RAM | `mem_fraction = 0.75` par défaut, converti en valeur absolue (DuckDB n'accepte pas de `%`). Détection RAM en base R, repli sur le défaut DuckDB si échec. |
| Threads | `threads = NULL` par défaut = **tous les cœurs** (comportement natif DuckDB) ; plafonnable via un entier. |
| Base persistante | Possible via `dbdir` (défaut `:memory:`). |
| Parquet / CSV / lazy | **Vue par défaut** ; matérialisation possible via `materialize = TRUE`. |
| Écrasement | `overwrite = FALSE` par défaut (erreur si l'objet existe ; `CREATE OR REPLACE` si `TRUE`). |
| `dir` (loaders) | Sémantique « répertoire contenant le fichier » ; défaut `"."`. |
| CSV | Détection auto par défaut ; `delim` et `header` forçables (`header = TRUE` par défaut). |
| `explore` | Tables **et** vues, multi-catalogs (y compris base Postgres attachée), `row_count` optionnel. |
| Postgres | Fonction dédiée `duckr_attach_postgres()` (extension DuckDB `postgres`). |
| Icônes console | Symboles `cli` : **✓ vert** (succès) / **✗ rouge** (échec). |
| Tests | Inclus (`testthat`). |
| Livrable | Package R complet (structure standard). |

---

## 3. Conventions

### 3.1 Dépendances (minimum)

- **Imports :** `DBI`, `duckdb`, `dbplyr`, `cli`.
- **Suggests :** `testthat` (≥ 3.0.0).
- Détection RAM/cœurs : base R (`system2`, `parallel`) → **aucune dépendance ajoutée**.
- PostgreSQL : géré par l'extension DuckDB `postgres` → **aucun driver R requis**.

### 3.2 Licence

MIT par défaut (à ajuster si besoin).

### 3.3 Structure du package

```
duckR/
├── DESCRIPTION
├── NAMESPACE                 # généré par roxygen2
├── R/
│   ├── duckR-package.R       # doc package + imports roxygen
│   ├── connection.R          # duckr_connect, duckr_con, duckr_close
│   ├── add.R                 # duckr_add_lazy, duckr_add_parquet, duckr_add_csv
│   ├── explore.R             # duckr_explore, duckr_status
│   ├── attach.R              # duckr_attach_postgres
│   └── utils.R               # env interne, détection RAM/cœurs, helpers SQL, icônes cli
├── man/                      # généré par roxygen2
├── tests/
│   ├── testthat.R
│   └── testthat/
│       └── test-*.R
└── README.md
```

---

## 4. Mécanisme de connexion par défaut

- Un **environnement interne** au package (non exporté) conserve la connexion « courante ».
- `duckr_connect()` crée la connexion, la **renvoie** (assignable : `con <- duckr_connect()`) **et** l'enregistre comme connexion courante.
- Toutes les autres fonctions ont l'argument `con = duckr_con()`.
- `duckr_con()` renvoie la connexion courante ; **erreur `cli` explicite** si aucune connexion n'est active.
- Une connexion explicite peut toujours être passée à n'importe quelle fonction, ce qui prime sur le défaut interne.
- `duckr_close()` ferme la connexion et **vide** la référence interne si c'était la connexion courante.

---

## 5. Gestion mémoire & threads

### 5.1 Mémoire

1. Déterminer la **RAM totale** de la machine, de façon multiplateforme et sans dépendance :
   - Linux : `MemTotal` dans `/proc/meminfo` ;
   - macOS : `sysctl -n hw.memsize` ;
   - Windows : PowerShell `(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory`.
2. Calculer `memory_limit = mem_fraction × RAM_totale`, formaté en valeur absolue acceptée par DuckDB (ex. `"12GB"` / `"512MB"`).
3. Appliquer via `DBI::dbExecute(con, "SET memory_limit='…'")`.
4. **Repli :** si la détection échoue, ne pas fixer `memory_limit` (DuckDB conserve son défaut ≈ 80 % RAM) et émettre un **avertissement `cli`**.

### 5.2 Threads

- `threads = NULL` (défaut) → on ne modifie rien : DuckDB utilise **tous les cœurs**.
- `threads = N` (entier) → `SET threads = N`.
- **Garde-fou :** DuckDB exige ≥ 128 Mo par thread. Vérifier `mem_fraction × RAM ≥ 128 Mo × threads_effectifs` (threads détectés via `parallel::detectCores()` si `threads = NULL`) ; sinon **avertissement `cli`**.

---

## 6. Spécification des fonctions

### 6.1 `duckr_connect()`

```r
duckr_connect(dbdir = ":memory:", mem_fraction = 0.75, threads = NULL)
```

- **Paramètres**
  - `dbdir` : `:memory:` (défaut) ou chemin vers un fichier `.duckdb` pour une base persistante.
  - `mem_fraction` : fraction de la RAM totale allouée à `memory_limit` (0–1).
  - `threads` : `NULL` (tous les cœurs) ou entier.
- **Comportement :** ouvre la connexion (`DBI::dbConnect(duckdb::duckdb(), dbdir = …)`), applique mémoire et threads (§5), enregistre comme connexion courante.
- **Retour :** l'objet connexion DBI.
- **Console :** **✓ vert** si OK (rappelant `dbdir`, limite mémoire, threads), **✗ rouge** si échec.

### 6.2 `duckr_con()`

```r
duckr_con()
```

- Renvoie la connexion courante.
- **Erreur `cli`** claire si aucune connexion active.

### 6.3 `duckr_add_lazy()`

```r
duckr_add_lazy(lazy, name, con = duckr_con(), materialize = FALSE, overwrite = FALSE)
```

- **Pré-condition :** `lazy` doit être bâtie **sur `con`** ; on vérifie `dbplyr::remote_con(lazy)` ≡ `con`, **erreur** sinon.
- Rend le SQL via `dbplyr::sql_render(lazy)`.
- Exécute `CREATE [OR REPLACE] {VIEW | TABLE} "name" AS <sql>` (vue si `materialize = FALSE`).
- **Retour :** `con` (invisible) ; message indiquant l'objet créé.

### 6.4 `duckr_add_parquet()`

```r
duckr_add_parquet(file, dir = ".", name, con = duckr_con(),
                  materialize = FALSE, overwrite = FALSE)
```

- Chemin résolu : `file.path(dir, file)`.
- Exécute `CREATE [OR REPLACE] {VIEW | TABLE} "name" AS SELECT * FROM read_parquet('<chemin>')`.
- **Retour :** `con` (invisible) + message.

### 6.5 `duckr_add_csv()`

```r
duckr_add_csv(file, dir = ".", name, con = duckr_con(),
              delim = NULL, header = TRUE, materialize = FALSE, overwrite = FALSE)
```

- Chemin résolu : `file.path(dir, file)`.
- `delim = NULL` → détection automatique ; `delim` fourni → délimiteur forcé. `header` transmis à DuckDB (`read_csv` / `read_csv_auto`).
- Exécute `CREATE [OR REPLACE] {VIEW | TABLE} "name" AS SELECT * FROM read_csv('<chemin>', …)`.
- **Retour :** `con` (invisible) + message.

### 6.6 `duckr_explore()`

```r
duckr_explore(con = duckr_con(), row_count = TRUE)
```

- Liste **tables et vues** de **tous les catalogs** (base mémoire/fichier + bases attachées, dont Postgres), via `information_schema.tables` (ou `duckdb_tables()` / `duckdb_views()`).
- **Retour :** un `data.frame` avec, au minimum : `catalog`, `schema`, `name`, `type` (`table` / `view`), `n_rows`.
- `row_count = TRUE` → `SELECT count(*)` par objet. ⚠️ Sur une base **Postgres attachée** ou des **vues** sur gros fichiers, le comptage peut être coûteux/distant ; `row_count = FALSE` renvoie `n_rows = NA`.

### 6.7 `duckr_status()`

```r
duckr_status(con = duckr_con())
```

- Renvoie / affiche l'état de la connexion :
  - type de base (mémoire ou fichier, + chemin) ;
  - `memory_limit` courant ;
  - mémoire utilisée ;
  - nombre de threads ;
  - nombre d'objets (tables + vues) ;
  - version de DuckDB.
- Sources d'introspection : `PRAGMA database_size`, `current_setting('memory_limit')`, `current_setting('threads')`, `version()` (requêtes exactes confirmées à l'implémentation, §10).

### 6.8 `duckr_attach_postgres()`

```r
duckr_attach_postgres(conn, alias, con = duckr_con(), read_only = TRUE)
```

- Charge l'extension : `INSTALL postgres; LOAD postgres;`.
- Attache : `ATTACH '<conn>' AS "<alias>" (TYPE postgres, READ_ONLY <read_only>);`.
- `conn` : chaîne de connexion libpq (ex. `"host=… port=… dbname=… user=… password=…"`).
- **Console :** **✓ vert** / **✗ rouge**.
- Après attache, les objets Postgres apparaissent dans `duckr_explore()`.

### 6.9 `duckr_close()`

```r
duckr_close(con = duckr_con())
```

- `DBI::dbDisconnect(con, shutdown = TRUE)`.
- Vide la référence interne si `con` était la connexion courante.
- Gère proprement le cas d'une connexion déjà fermée/invalide.
- **Console :** **✓ vert** / **✗ rouge**.

---

## 7. Comportements transverses

- **Vue par défaut** pour `add_lazy`, `add_parquet`, `add_csv` (`materialize = FALSE`). `materialize = TRUE` → `CREATE TABLE … AS …`.
- **Écrasement :** `overwrite = FALSE` → erreur si l'objet existe ; `overwrite = TRUE` → `CREATE OR REPLACE`.
- **Pipe-friendly :** les loaders renvoient la connexion de façon invisible, permettant l'enchaînement avec `|>`.
- **Icônes `cli` :** uniquement sur les fonctions de connexion / déconnexion / attache (`connect`, `close`, `attach_postgres`). ✓ vert = succès, ✗ rouge = échec.
- **Identifiants SQL :** noms de tables et alias correctement échappés (quoting) pour éviter les injections / collisions de mots réservés.

---

## 8. Exemples d'utilisation (API cible)

```r
library(duckR)

# Connexion (mémoire, 75 % RAM, tous les cœurs)
con <- duckr_connect()                      # ✓ vert

# Connexion persistante, 50 % RAM, 4 threads
con <- duckr_connect("data/ma_base.duckdb", mem_fraction = 0.5, threads = 4)

# Charger un parquet en vue
duckr_add_parquet("ventes.parquet", dir = "data", name = "ventes")

# Charger un CSV en forçant le séparateur
duckr_add_csv("clients.csv", dir = "data", name = "clients", delim = ";")

# Charger le résultat d'une requête dbplyr (bâtie sur con), matérialisée
library(dplyr)
agg <- tbl(con, "ventes") |>
  group_by(region) |>
  summarise(ca = sum(montant))
duckr_add_lazy(agg, name = "ca_region", materialize = TRUE)

# Attacher une base Postgres
duckr_attach_postgres("host=localhost dbname=prod user=lecture", alias = "pg")

# Explorer / suivre
duckr_explore()                              # tables + vues + objets pg
duckr_status()                               # mémoire, threads, version…

# Requêtes : on reste sur DBI / SQL
DBI::dbGetQuery(con, "SELECT * FROM ca_region")

# Fermeture
duckr_close()                                # ✓ vert
```

---

## 9. Tests (`testthat`)

Tests exécutés sur une base **mémoire** (sans I/O réseau) :

- `duckr_connect()` : connexion ouverte, enregistrée comme courante, limite mémoire appliquée ; repli si RAM non détectée.
- `duckr_con()` : renvoie la connexion ; erreur si aucune.
- `duckr_add_parquet()` / `duckr_add_csv()` : création de vue puis de table ; `overwrite` ; détection vs `delim`/`header` forcés ; erreur si objet existe.
- `duckr_add_lazy()` : création depuis une requête `dbplyr` ; **erreur** si la requête provient d'une autre connexion.
- `duckr_explore()` : présence des tables **et** vues ; `row_count` TRUE/FALSE.
- `duckr_status()` : champs attendus présents.
- `duckr_close()` : déconnexion ; référence interne vidée ; robustesse sur connexion déjà fermée.

> `duckr_attach_postgres()` : test léger (extension chargeable / forme de la requête) sans serveur Postgres réel, ou ignoré (`skip`) si indisponible.

---

## 10. Points confirmés à l'implémentation

Détails techniques à verrouiller contre la version DuckDB installée (sans impact sur l'API publique ci-dessus) :

- Requêtes exactes d'introspection pour `duckr_status()` (`PRAGMA database_size`, `duckdb_memory()`, `current_setting(...)`, `version()`).
- Syntaxe précise de `read_csv` / `read_csv_auto` selon que `delim` est fourni ou non.
- Forme finale de la chaîne de connexion et des options de `ATTACH … (TYPE postgres)`.
- Format de sortie de `memory_limit` (`MB` vs `GB`) et arrondis.
