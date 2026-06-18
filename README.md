# duckR

Surcouche **légère** à [DuckDB](https://duckdb.org), orientée **SQL + DBI**. duckR
n'essaie pas de réimplémenter dplyr : il facilite l'ouverture d'une connexion DuckDB
sobre en mémoire, le chargement de fichiers Parquet/CSV et de requêtes `dbplyr`,
l'export de tables, l'exploration de la connexion et l'attachement d'une base
PostgreSQL — tout en laissant la requête à SQL et à `DBI`.

## Installation

```r
# install.packages("remotes")
remotes::install_github("gschone-data/duckR")
```

## Démarrage rapide

```r
library(duckR)

# Connexion en mémoire (75 % de la RAM, tous les cœurs). La connexion est renvoyée
# *et* enregistrée comme connexion « courante ».
con <- duckr_connect()

# Charger un CSV livré avec le package, comme vue
csv <- system.file("extdata", "penguins.csv", package = "duckR")
duckr_add_csv(basename(csv), dir = dirname(csv), name = "penguins")

# On reste sur DBI / SQL pour les requêtes
DBI::dbGetQuery(
  con,
  "SELECT species, count(*) AS n FROM penguins GROUP BY species"
)

duckr_close()
```

Les fonctions reçoivent toutes `con = duckr_con()` : par défaut elles utilisent la
connexion courante, mais une connexion explicite passée en argument prime.

## Connexion

```r
con <- duckr_connect()                                   # mémoire, ✓ vert
con <- duckr_connect("ma_base.duckdb", mem_fraction = 0.5, threads = 4)  # persistante
duckr_con()       # récupère la connexion courante
duckr_close()     # ferme et vide la référence interne, ✗/✓
```

`mem_fraction` est convertie en valeur absolue (`memory_limit`), DuckDB n'acceptant
pas de pourcentage ; repli silencieux sur le défaut DuckDB si la RAM n'est pas
détectable. `threads = NULL` laisse DuckDB utiliser tous les cœurs.

## Charger des données

Tous les loaders créent une **vue** par défaut (`materialize = FALSE`) ; passez
`materialize = TRUE` pour une table matérialisée. `overwrite = FALSE` par défaut
(erreur si l'objet existe ; `TRUE` → remplacement). Ils renvoient `con` de façon
invisible (chaînables avec `|>`).

```r
# Fichiers
duckr_add_csv("clients.csv", dir = "data", name = "clients", delim = ";")
duckr_add_parquet("ventes.parquet", dir = "data", name = "ventes")

# Data frame R (vue adossée à l'objet R, ou table autonome si materialize = TRUE)
duckr_add_df(iris, name = "iris", materialize = TRUE)

# Requête dbplyr (doit être bâtie sur `con`)
library(dplyr)
agg <- tbl(con, "ventes") |>
  group_by(region) |>
  summarise(ca = sum(montant))
duckr_add_lazy(agg, name = "ca_region", materialize = TRUE)
```

## Exporter des données

```r
duckr_to_parquet("penguins", "penguins.parquet", dir = tempdir())
duckr_to_csv("penguins", "penguins.csv", dir = tempdir(), delim = ";")
```

`overwrite = FALSE` par défaut : erreur si le fichier de sortie existe déjà.

## Explorer & suivre

```r
duckr_explore()                 # tables + vues de tous les catalogs (+ n_rows)
duckr_explore(row_count = FALSE)  # sans comptage (n_rows = NA)
duckr_status()                  # base, memory_limit, mémoire utilisée, threads, version…
```

## PostgreSQL

Attachement via l'extension DuckDB `postgres` (aucun driver R requis) :

```r
duckr_attach_postgres("host=localhost dbname=prod user=lecture", alias = "pg")
duckr_explore()   # les objets Postgres apparaissent dans la liste
```

## Conventions

- Préfixe `duckr_`, connexion courante gérée par un environnement interne (pas de
  variable globale).
- Identifiants SQL systématiquement quotés (`DBI::dbQuoteIdentifier`).
- Feedback console `cli` ✓ vert / ✗ rouge réservé à `duckr_connect`, `duckr_close`
  et `duckr_attach_postgres`.
- Dépendances minimales : `DBI`, `duckdb`, `dbplyr`, `cli`.

## Licence

MIT — voir [LICENSE](LICENSE).
