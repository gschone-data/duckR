#' Add a dbplyr lazy query as a view or table
#'
#' Renders a `dbplyr` lazy query to SQL and creates a view (default) or a
#' materialised table from it.
#'
#' @param lazy A `dbplyr` lazy query. It must be built on `con`.
#' @param name Name of the object to create.
#' @param con A DBI connection. Defaults to the current connection.
#' @param materialize If `FALSE` (default) create a `VIEW`; if `TRUE` create a
#'   `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   use `CREATE OR REPLACE`.
#'
#' @return The connection `con`, invisibly.
#' @export
duckr_add_lazy <- function(
  lazy,
  name,
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
  type <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  cli::cli_inform("Created {type} {.val {name}}.")
  invisible(con)
}

#' Add a Parquet file as a view or table
#'
#' @param file Parquet file name.
#' @param dir Directory containing `file`. Defaults to `"."`.
#' @param name Name of the object to create.
#' @param con A DBI connection. Defaults to the current connection.
#' @param materialize If `FALSE` (default) create a `VIEW`; if `TRUE` create a
#'   `TABLE`.
#' @param overwrite If `FALSE` (default) error when the object exists; if `TRUE`
#'   use `CREATE OR REPLACE`.
#'
#' @return The connection `con`, invisibly.
#' @export
duckr_add_parquet <- function(
  file,
  dir = ".",
  name,
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
  type <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  cli::cli_inform("Created {type} {.val {name}} from {.file {path}}.")
  invisible(con)
}

#' Add a CSV file as a view or table
#'
#' @param file CSV file name.
#' @param dir Directory containing `file`. Defaults to `"."`.
#' @param name Name of the object to create.
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
#' @export
duckr_add_csv <- function(
  file,
  dir = ".",
  name,
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
  type <- duckr_create_as(con, name, select_sql, materialize, overwrite)
  cli::cli_inform("Created {type} {.val {name}} from {.file {path}}.")
  invisible(con)
}
