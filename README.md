# 🦆 duckR

Surcouche **légère** à [DuckDB](https://duckdb.org), orientée **SQL + DBI**.

duckR facilite l'ouverture d'une connexion DuckDB sobre en mémoire, le chargement de fichiers Parquet/CSV et de requêtes `dbplyr`, l'export de tables, l'exploration de la connexion et l'attachement d'une base PostgreSQL — tout en laissant la requête à SQL et à `DBI`.

## 📦 Installation

``` r
# install.packages("remotes")
remotes::install_github("gschone-data/duckR")
```

## 🚀 Démarrage rapide

``` r
library(duckR)

# Connexion en mémoire (75 % de la RAM, tous les cœurs). La connexion est renvoyée *et* enregistrée comme connexion « courante ».
con <- duckr_connect()

# Charger un CSV livré avec le package, comme vue
csv <- system.file("extdata", "penguins.csv", package = "duckR")
duckr_add_csv(basename(csv), dir = dirname(csv), name = "penguins")

# Interroger avec dplyr : `tbl()` ouvre une table paresseuse, la requête est
# traduite en SQL et exécutée par DuckDB
library(dplyr)
tbl(con, "penguins") |>
  count(species)

# …ou rester sur DBI / SQL si on préfère
DBI::dbGetQuery(
  con,
  "SELECT species, count(*) AS n FROM penguins GROUP BY species"
)

duckr_close()
```

Les fonctions reçoivent toutes `con = duckr_con()` : par défaut elles utilisent la connexion courante, mais une connexion explicite passée en argument prime.

## 🔌 Connexion

``` r
con <- duckr_connect()                                   # mémoire, ✓ vert
con <- duckr_connect("ma_base.duckdb", mem_fraction = 0.5, threads = 4)  # persistante
duckr_con()       # récupère la connexion courante
duckr_close()     # ferme la connexion courante, ✗/✓
duckr_close_all() # ferme toutes les connexions ouvertes
```

Les connexions sont empilées : la connexion courante est la dernière ouverte. `duckr_close()` ferme la connexion courante et restaure la précédente comme courante ; des appels successifs les ferment toutes dans l'ordre. `duckr_close_all()` ferme tout en un seul appel.

`mem_fraction` est convertie en valeur absolue (`memory_limit`), DuckDB n'acceptant pas de pourcentage ; repli silencieux sur le défaut DuckDB si la RAM n'est pas détectable. `threads = NULL` laisse DuckDB utiliser tous les cœurs.

## 📥 Charger des données

Tous les loaders créent une **vue** par défaut (`materialize = FALSE`) ; passez `materialize = TRUE` pour une table matérialisée. `overwrite = FALSE` par défaut (erreur si l'objet existe ; `TRUE` → remplacement). Ils renvoient `con` de façon invisible (chaînables avec `|>`).

``` r
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

# La table enregistrée se réinterroge avec dplyr via `tbl()`
tbl(con, "ca_region") |>
  arrange(desc(ca))
```

## 📤 Exporter des données

``` r
duckr_to_parquet("penguins", "penguins.parquet", dir = tempdir())
duckr_to_csv("penguins", "penguins.csv", dir = tempdir(), delim = ";")
```

`overwrite = FALSE` par défaut : erreur si le fichier de sortie existe déjà.

## 💾 Sauvegarder la base

`duckr_save_database()` persiste une base **en mémoire** vers un fichier `.duckdb` (attache le fichier cible puis `COPY FROM DATABASE`). La connexion vivante reste en mémoire et intacte.

``` r
duckr_save_database("backup.duckdb", dir = "data")
```

-   🦆 Utile uniquement pour une base `:memory:`. Si la connexion est **déjà adossée à un fichier**, rien n'est copié et un avertissement indique où la base est déjà stockée.
-   ⚠️ Les **vues** sont copiées comme définition (pas comme données) : un avertissement les liste. Une vue ne se recharge que si tous les objets qu'elle lit sont aussi sauvegardés — pensez à `materialize = TRUE` pour les figer.
-   `overwrite = FALSE` par défaut : erreur si le fichier de sortie existe déjà.

## 🔍 Explorer & suivre

``` r
duckr_explore()                 # tables + vues de tous les catalogs (+ n_rows)
duckr_explore(row_count = FALSE)  # sans comptage (n_rows = NA)
duckr_status()                  # base, memory_limit, mémoire utilisée, threads, version…
```

## 🐘 PostgreSQL

Attachement via l'extension DuckDB `postgres` (aucun driver R requis) :

``` r
duckr_attach_postgres("host=localhost dbname=prod user=lecture", alias = "pg")
duckr_explore()   # les objets Postgres apparaissent dans la liste

# Les tables Postgres se requêtent aussi avec dplyr ; `pg.clients` désigne la
# table `clients` du catalog attaché `pg`
library(dplyr)
tbl(con, "pg.clients") |>
  filter(actif) |>
  count(region)
```

## 📄 Licence

MIT — voir [LICENSE](LICENSE).
