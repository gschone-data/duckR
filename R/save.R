# Backing file of the connection's main database, or NA_character_ when the
# database lives in memory (`:memory:`). Attached catalogs are ignored.
duckr_main_db_file <- function(con) {
  main <- DBI::dbGetQuery(con, "SELECT current_database() AS db")$db
  info <- DBI::dbGetQuery(con, "PRAGMA database_list")
  row <- info[info$name == main, , drop = FALSE]
  file <- if (nrow(row) == 0L) NA_character_ else row$file[1]
  if (is.na(file) || !nzchar(file)) NA_character_ else file
}

# Pick a catalog alias not already in use by the connection.
duckr_free_alias <- function(con, base = "duckr_save_target") {
  used <- DBI::dbGetQuery(con, "PRAGMA database_list")$name
  alias <- base
  i <- 1L
  while (alias %in% used) {
    alias <- paste0(base, "_", i)
    i <- i + 1L
  }
  alias
}

#' Save an in-memory database to a file
#'
#' Persists the whole current in-memory DuckDB database to a `.duckdb` file by
#' attaching the target file and copying every catalog object (tables and
#' views) into it. The live connection is left untouched and still in memory.
#'
#' Only useful for an in-memory database: when the connection is already backed
#' by a file, nothing is copied and a warning reports where the database
#' already lives.
#'
#' @param file Output `.duckdb` file name.
#' @param dir Directory to write `file` into. Defaults to `"."`.
#' @param con A DBI connection. Defaults to the current connection.
#' @param overwrite If `FALSE` (default) error when the output file exists; if
#'   `TRUE` overwrite it.
#'
#' @return The connection `con`, invisibly.
#' @family data exporters
#' @examples
#' con <- duckr_connect()
#' duckr_add_df(mtcars, name = "cars")
#' duckr_save_database("backup.duckdb", dir = tempdir())
#' duckr_close()
#' @export
duckr_save_database <- function(
  file,
  dir = ".",
  con = duckr_con(),
  overwrite = FALSE
) {
  existing <- duckr_main_db_file(con)
  if (!is.na(existing)) {
    cli::cli_warn(c(
      "Not needed: database is already stored.",
      "i" = "File: {.file {existing}}"
    ))
    return(invisible(con))
  }

  path <- file.path(dir, file)
  duckr_check_out_file(path, overwrite)
  if (isTRUE(overwrite) && file.exists(path)) {
    unlink(path)
  }

  source_db <- DBI::dbGetQuery(con, "SELECT current_database() AS db")$db
  views <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT view_name FROM duckdb_views() ",
      "WHERE database_name = ",
      DBI::dbQuoteString(con, source_db),
      " AND NOT internal ORDER BY view_name"
    )
  )$view_name
  if (length(views) > 0L) {
    cli::cli_warn(c(
      "Copying {length(views)} view{?s} as {?its/their} definition, not data.",
      "i" = "Views: {.val {views}}.",
      "!" = "A view reloads only if every object it reads is also saved; one \\
             over a registered data frame or temporary source will not."
    ))
  }
  alias <- duckr_free_alias(con)
  DBI::dbExecute(
    con,
    paste0(
      "ATTACH ",
      DBI::dbQuoteString(con, path),
      " AS ",
      DBI::dbQuoteIdentifier(con, alias)
    )
  )
  on.exit(
    DBI::dbExecute(con, paste0("DETACH ", DBI::dbQuoteIdentifier(con, alias))),
    add = TRUE
  )
  DBI::dbExecute(
    con,
    paste0(
      "COPY FROM DATABASE ",
      DBI::dbQuoteIdentifier(con, source_db),
      " TO ",
      DBI::dbQuoteIdentifier(con, alias)
    )
  )

  cli::cli_inform("Saved database to {.file {path}}.")
  invisible(con)
}
