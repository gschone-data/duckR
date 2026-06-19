#' List tables and views
#'
#' Lists tables and views across all catalogs (the in-memory/file database plus
#' any attached database, including PostgreSQL), with an optional row count.
#'
#' @param con A DBI connection. Defaults to the current connection.
#' @param row_count If `TRUE` (default) run `SELECT count(*)` per object; if
#'   `FALSE`, `n_rows` is `NA`. Counting can be expensive on attached
#'   PostgreSQL databases or views over large files.
#'
#' @return A data frame with columns `catalog`, `schema`, `name`, `type`
#'   (`"table"` or `"view"`) and `n_rows`.
#'
#' @details
#' System schemas (`information_schema`, `pg_catalog`) are excluded from every
#' catalog, including attached PostgreSQL databases. This keeps the listing to
#' user objects and avoids `count(*)` hitting restricted PostgreSQL system
#' views (e.g. `_pg_foreign_data_wrappers`), which would raise a
#' *permission denied* error.
#' @family exploration functions
#' @examples
#' con <- duckr_connect()
#' duckr_add_df(mtcars, name = "cars")
#' duckr_explore()
#' duckr_close()
#' @export
duckr_explore <- function(con = duckr_con(), row_count = TRUE) {
  objects <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT table_catalog AS catalog, table_schema AS schema, ",
      "table_name AS name, ",
      "CASE table_type WHEN 'VIEW' THEN 'view' ELSE 'table' END AS type ",
      "FROM information_schema.tables ",
      "WHERE table_schema NOT IN ('information_schema', 'pg_catalog') ",
      "ORDER BY table_catalog, table_schema, table_name"
    )
  )

  objects$n_rows <- rep(NA_real_, nrow(objects))
  if (isTRUE(row_count) && nrow(objects) > 0L) {
    objects$n_rows <- vapply(
      seq_len(nrow(objects)),
      function(i) {
        qualified <- paste0(
          DBI::dbQuoteIdentifier(con, objects$catalog[i]),
          ".",
          DBI::dbQuoteIdentifier(con, objects$schema[i]),
          ".",
          DBI::dbQuoteIdentifier(con, objects$name[i])
        )
        as.numeric(
          DBI::dbGetQuery(
            con,
            paste0("SELECT count(*) AS n FROM ", qualified)
          )$n
        )
      },
      numeric(1)
    )
  }
  objects
}

#' Report the state of a DuckDB connection
#'
#' @param con A DBI connection. Defaults to the current connection.
#'
#' @return A one-row data frame with the database location, type
#'   (`"memory"`/`"file"`), memory limit, memory used, thread count, number of
#'   objects (tables + views) and the DuckDB version.
#' @family exploration functions
#' @examples
#' con <- duckr_connect()
#' duckr_status()
#' duckr_close()
#' @export
duckr_status <- function(con = duckr_con()) {
  dblist <- DBI::dbGetQuery(con, "PRAGMA database_list")
  main <- dblist$name[!dblist$name %in% c("system", "temp")][1]
  file <- dblist$file[dblist$name == main][1]

  size <- DBI::dbGetQuery(con, "PRAGMA database_size")
  size_row <- size[size$database_name == main, ]
  memory_used <- if (nrow(size_row) > 0L) {
    size_row$memory_usage[1]
  } else {
    NA_character_
  }

  data.frame(
    database = if (is.na(file)) ":memory:" else file,
    type = if (is.na(file)) "memory" else "file",
    memory_limit = DBI::dbGetQuery(
      con,
      "SELECT current_setting('memory_limit') AS m"
    )$m,
    memory_used = memory_used,
    threads = as.integer(
      DBI::dbGetQuery(
        con,
        "SELECT current_setting('threads') AS t"
      )$t
    ),
    n_objects = as.integer(
      DBI::dbGetQuery(
        con,
        paste0(
          "SELECT count(*) AS n FROM information_schema.tables ",
          "WHERE table_schema NOT IN ('information_schema', 'pg_catalog')"
        )
      )$n
    ),
    duckdb_version = DBI::dbGetQuery(con, "SELECT version() AS v")$v,
    stringsAsFactors = FALSE
  )
}
