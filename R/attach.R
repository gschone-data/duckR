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
#'   `"host=... port=... dbname=... user=... password=..."`.
#' @param alias Catalog alias for the attached database.
#' @param con A DBI connection. Defaults to the current connection.
#' @param read_only Whether to attach read-only. Defaults to `TRUE`.
#'
#' @return The connection `con`, invisibly.
#' @seealso [duckr_explore()] to list the attached database's objects.
#' @examples
#' \dontrun{
#' duckr_connect()
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
