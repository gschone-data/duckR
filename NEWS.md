# duckR 0.1.0

* First release: a lightweight DuckDB wrapper maximising SQL and DBI.
* `duckr_add_csv()`, `duckr_add_parquet()` and `duckr_add_lazy()` load CSV
  files, Parquet files and dbplyr lazy queries as views (or materialised tables
  with `materialize = TRUE`).
* `duckr_attach_postgres()` attaches an external PostgreSQL database via the
  DuckDB `postgres` extension.
* `duckr_connect()`, `duckr_con()` and `duckr_close()` manage a memory-aware
  DuckDB connection registered as the current one.
* `duckr_explore()` lists tables and views across all catalogs and
  `duckr_status()` reports the connection state.
