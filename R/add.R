#' Add a dbplyr lazy query as a view or table
#'
#' Renders a `dbplyr` lazy query to SQL and creates a view (default) or a
#' materialised table from it.
#'
#' @param lazy A `dbplyr` lazy query. It must be built on `con`.
#' @param name Name of the object to create. Defaults to the name of the `lazy`
#'   argument.
#' @param con A DBI connection. Defaults to the current connection.
#' @param materialize If `FALSE` (default) create a `VIEW`; if `TRUE` create a
#'   `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   use `CREATE OR REPLACE`.
#'
#' @return The connection `con`, invisibly.
#' @family data loaders
#' @examples
#' \dontrun{
#' con <- duckr_connect()
#' DBI::dbExecute(con, "CREATE TABLE t AS SELECT 1 AS x")
#' duckr_add_lazy(dplyr::tbl(con, "t"), name = "v")
#' duckr_close()
#' }
#' @export
duckr_add_lazy <- function(
  lazy,
  name = deparse1(substitute(lazy)),
  con = duckr_con(),
  materialize = FALSE,
  overwrite = FALSE
) {
  remote <- dbplyr::remote_con(lazy)
  if (is.null(remote) || !identical(remote, con)) {
    cli::cli_abort(c(
      "{.arg lazy} must be built on the same connection as {.arg con}.",
      "i" = "Rebuild the query with {.code dplyr::tbl(con, ...)}."
    ))
  }
  select_sql <- as.character(dbplyr::sql_render(lazy))
  res <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  if (res$type == "table") {
    cli::cli_inform("Created {res$type} {.val {name}} ({res$n} row{?s}).")
  } else {
    cli::cli_inform("Created {res$type} {.val {name}}.")
  }
  invisible(con)
}

#' Add an R data frame as a view or table
#'
#' Brings an R `data.frame` into the connection. By default it is registered as
#' a virtual view backed by the live R object; materialising copies the data
#' into a standalone DuckDB table.
#'
#' @details
#' A non-materialised `df` is registered with [duckdb::duckdb_register()], which
#' binds the view to the live R object. DuckDB always places such session-scoped
#' views in the `temp` catalog (rather than `memory` like the SQL-based
#' loaders), because they cannot be persisted independently of the R object.
#' Materialising (`materialize = TRUE`) copies the data into a standalone table
#' in the `memory` catalog.
#'
#' @param df A `data.frame` to add.
#' @param name Name of the object to create. Defaults to the name of the `df`
#'   argument.
#' @param con A DBI connection. Defaults to the current connection.
#' @param materialize If `FALSE` (default) register `df` as a `VIEW` backed by
#'   the live R object; if `TRUE` copy it into a standalone `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   replace it.
#'
#' @return The connection `con`, invisibly.
#' @family data loaders
#' @examples
#' con <- duckr_connect()
#' duckr_add_df(mtcars, name = "cars")
#' DBI::dbGetQuery(con, "SELECT count(*) AS n FROM cars")
#' duckr_close()
#' @export
duckr_add_df <- function(
  df,
  name = deparse1(substitute(df)),
  con = duckr_con(),
  materialize = FALSE,
  overwrite = FALSE
) {
  duckr_drop_if_exists(con, name, overwrite)
  # duckr_drop_if_exists already removes a previously registered df-view via its
  # DROP; this unregister is belt-and-suspenders (no-op when nothing is bound).
  duckdb::duckdb_unregister(con, name)

  if (isTRUE(materialize)) {
    DBI::dbWriteTable(con, name, df)
    type <- "table"
  } else {
    duckdb::duckdb_register(con, name, df)
    type <- "view"
  }
  n <- nrow(df)
  cli::cli_inform("Created {type} {.val {name}} ({n} row{?s}).")
  invisible(con)
}

#' Add a Parquet file as a view or table
#'
#' @param file Parquet file name.
#' @param dir Directory containing `file`. Defaults to `"."`.
#' @param name Name of the object to create. Defaults to `file` without its
#'   extension.
#' @param con A DBI connection. Defaults to the current connection.
#' @param materialize If `FALSE` (default) create a `VIEW`; if `TRUE` create a
#'   `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   use `CREATE OR REPLACE`.
#'
#' @return The connection `con`, invisibly.
#' @family data loaders
#' @examples
#' con <- duckr_connect()
#' pq <- system.file("extdata", "penguins.parquet", package = "duckR")
#' duckr_add_parquet(basename(pq), dir = dirname(pq), name = "penguins")
#' duckr_close()
#' @export
duckr_add_parquet <- function(
  file,
  dir = ".",
  name = tools::file_path_sans_ext(basename(file)),
  con = duckr_con(),
  materialize = FALSE,
  overwrite = FALSE
) {
  path <- file.path(dir, file)
  select_sql <- paste0(
    "SELECT * FROM read_parquet(",
    DBI::dbQuoteString(con, path),
    ")"
  )
  res <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  if (res$type == "table") {
    cli::cli_inform(
      "Created {res$type} {.val {name}} from {.file {path}} ({res$n} row{?s})."
    )
  } else {
    cli::cli_inform("Created {res$type} {.val {name}} from {.file {path}}.")
  }
  invisible(con)
}

#' Add a CSV file as a view or table
#'
#' @param file CSV file name.
#' @param dir Directory containing `file`. Defaults to `"."`.
#' @param name Name of the object to create. Defaults to `file` without its
#'   extension.
#' @param con A DBI connection. Defaults to the current connection.
#' @param delim Field delimiter. `NULL` (default) lets DuckDB auto-detect it; a
#'   string forces the delimiter.
#' @param header Whether the file has a header row. Defaults to `TRUE`.
#' @param materialize If `FALSE` (default) create a `VIEW`; if `TRUE` create a
#'   `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   use `CREATE OR REPLACE`.
#'
#' @return The connection `con`, invisibly.
#' @family data loaders
#' @examples
#' con <- duckr_connect()
#' csv <- system.file("extdata", "penguins.csv", package = "duckR")
#' duckr_add_csv(basename(csv), dir = dirname(csv), name = "penguins")
#' duckr_close()
#' @export
duckr_add_csv <- function(
  file,
  dir = ".",
  name = tools::file_path_sans_ext(basename(file)),
  con = duckr_con(),
  delim = NULL,
  header = TRUE,
  materialize = FALSE,
  overwrite = FALSE
) {
  path <- file.path(dir, file)
  opts <- paste0("header=", if (isTRUE(header)) "true" else "false")
  if (is.null(delim)) {
    opts <- paste0(opts, ", auto_detect=true")
  } else {
    opts <- paste0("delim=", DBI::dbQuoteString(con, delim), ", ", opts)
  }
  select_sql <- paste0(
    "SELECT * FROM read_csv(",
    DBI::dbQuoteString(con, path),
    ", ",
    opts,
    ")"
  )
  res <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  if (res$type == "table") {
    cli::cli_inform(
      "Created {res$type} {.val {name}} from {.file {path}} ({res$n} row{?s})."
    )
  } else {
    cli::cli_inform("Created {res$type} {.val {name}} from {.file {path}}.")
  }
  invisible(con)
}
