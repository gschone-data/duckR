# Locate the libpq password file (PGPASSFILE overrides the default ~/.pgpass).
duckr_pgpass_path <- function() {
  env <- Sys.getenv("PGPASSFILE", unset = "")
  if (nzchar(env)) {
    return(env)
  }
  path.expand("~/.pgpass")
}

# Warn when the connection string relies on ~/.pgpass but the file is readable
# by group/other: libpq silently ignores an over-permissive password file, so
# the attach would fail or prompt instead of using the stored password.
duckr_warn_pgpass_perms <- function(conn) {
  if (.Platform$OS.type != "unix") {
    return(invisible())
  }
  if (grepl("(^|[[:space:]])password[[:space:]]*=", conn)) {
    return(invisible())
  }
  path <- duckr_pgpass_path()
  if (!file.exists(path)) {
    return(invisible())
  }
  mode <- file.info(path)$mode
  if (bitwAnd(as.integer(mode), as.integer(as.octmode("077"))) != 0L) {
    cli::cli_warn(c(
      "Password file {.path {path}} is readable by group/other \\
       (mode {format(mode)}); libpq will ignore it.",
      i = "Run {.code chmod 600 {path}} so the stored password is used."
    ))
  }
  invisible()
}

# Build the ATTACH statement for a PostgreSQL database.
duckr_attach_sql <- function(con, conn, alias, read_only) {
  opts <- "TYPE postgres"
  if (isTRUE(read_only)) {
    opts <- paste0(opts, ", READ_ONLY")
  }
  paste0(
    "ATTACH ",
    DBI::dbQuoteString(con, conn),
    " AS ",
    DBI::dbQuoteIdentifier(con, alias),
    " (",
    opts,
    ")"
  )
}

#' Attach an external PostgreSQL database
#'
#' Loads the DuckDB `postgres` extension and attaches a PostgreSQL database.
#' Once attached, its objects appear in [duckr_explore()].
#'
#' @param conn A libpq connection string, e.g.
#'   `"host=... port=... dbname=... user=..."`. Prefer omitting the password and
#'   storing it in a `.pgpass` file (see *Passwords*).
#' @param alias Catalog alias for the attached database.
#' @param con A DBI connection. Defaults to the current connection.
#' @param read_only Whether to attach read-only. Defaults to `TRUE`.
#'
#' @section Passwords (`.pgpass`):
#' DuckDB's `postgres` extension uses libpq, so you should **not** put the
#' password in `conn`. Omit `password=` and store the credentials in libpq's
#' password file instead — `~/.pgpass` on Unix (override with the `PGPASSFILE`
#' environment variable), one entry per line:
#'
#' ```
#' hostname:port:database:username:password
#' ```
#'
#' For example `localhost:5432:*:reader:s3cret`. The file **must** be readable
#' only by its owner (`chmod 600 ~/.pgpass`); libpq silently ignores a file
#' that group/other can read. `duckr_attach_postgres()` warns when `conn`
#' relies on `.pgpass` but the file's permissions are too open.
#'
#' @section Restricted PostgreSQL accounts:
#' [duckr_explore()] excludes the `information_schema` and `pg_catalog` schemas,
#' so listing objects on a least-privilege account no longer fails with
#' *permission denied for view `_pg_foreign_data_wrappers`* (and similar system
#' views). Only user schemas (e.g. `public`) are reported.
#'
#' @return The connection `con`, invisibly.
#' @seealso [duckr_explore()] to list the attached database's objects.
#' @examples
#' \dontrun{
#' duckr_connect()
#' # password read from ~/.pgpass, never hard-coded:
#' duckr_attach_postgres("host=localhost dbname=prod user=reader", alias = "pg")
#' duckr_explore()
#' duckr_close()
#' }
#' @export
duckr_attach_postgres <- function(
  conn,
  alias,
  con = duckr_con(),
  read_only = TRUE
) {
  duckr_warn_pgpass_perms(conn)

  ok <- tryCatch(
    {
      DBI::dbExecute(con, "INSTALL postgres")
      DBI::dbExecute(con, "LOAD postgres")
      DBI::dbExecute(con, duckr_attach_sql(con, conn, alias, read_only))
      TRUE
    },
    error = function(e) {
      cli::cli_alert_danger(
        "Failed to attach PostgreSQL database {.val {alias}}: {conditionMessage(e)}"
      )
      FALSE
    }
  )

  if (ok) {
    cli::cli_alert_success(
      "Attached PostgreSQL database as {.val {alias}} (read_only = {read_only})."
    )
  }
  invisible(con)
}
