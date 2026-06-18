#' Open a DuckDB connection
#'
#' Opens a DuckDB connection, applies a memory limit derived from the machine's
#' RAM, optionally caps the number of threads, and registers the connection as
#' the current one used by the other `duckr_*` functions.
#'
#' @param dbdir Path to a `.duckdb` file for a persistent database, or
#'   `":memory:"` (the default) for an in-memory database.
#' @param mem_fraction Fraction of total RAM (0-1) allocated to DuckDB's
#'   `memory_limit`. Converted to an absolute value because DuckDB does not
#'   accept percentages. If RAM cannot be detected, DuckDB's default limit is
#'   kept and a warning is emitted.
#' @param threads Number of threads. `NULL` (the default) keeps DuckDB's native
#'   behaviour (all cores); an integer caps the thread count.
#'
#' @return The DBI connection object, invisibly. It is also stored as the
#'   current connection (see [duckr_con()]).
#' @family connection functions
#' @examples
#' con <- duckr_connect()
#' duckr_status()
#' duckr_close()
#' @export
duckr_connect <- function(
  dbdir = ":memory:",
  mem_fraction = 0.75,
  threads = NULL
) {
  con <- tryCatch(
    DBI::dbConnect(duckdb::duckdb(), dbdir = dbdir),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to open DuckDB connection.",
        "x" = conditionMessage(e)
      ))
    }
  )

  ram <- duckr_total_ram()
  mem_label <- "DuckDB default"
  if (is.na(ram)) {
    cli::cli_warn(c(
      "Could not detect total RAM.",
      "i" = "Keeping DuckDB's default memory limit."
    ))
  } else {
    mem_label <- duckr_format_memory(ram * mem_fraction)
    DBI::dbExecute(
      con,
      paste0("SET memory_limit=", DBI::dbQuoteString(con, mem_label))
    )
    eff_threads <- if (is.null(threads)) parallel::detectCores() else threads
    if (!is.na(eff_threads) && ram * mem_fraction < 128e6 * eff_threads) {
      cli::cli_warn(c(
        "Memory limit may be too low for {eff_threads} thread{?s}.",
        "i" = "DuckDB requires at least 128 MB per thread."
      ))
    }
  }

  if (!is.null(threads)) {
    DBI::dbExecute(con, paste0("SET threads=", as.integer(threads)))
  }

  duckr_set_current(con)
  thr_label <- if (is.null(threads)) "all cores" else as.integer(threads)
  cli::cli_alert_success(
    "Connected to DuckDB ({.val {dbdir}}) | memory: {mem_label} | threads: {thr_label}"
  )
  invisible(con)
}

#' Get the current DuckDB connection
#'
#' Returns the connection registered by the most recent [duckr_connect()] call.
#' Used as the default `con` argument throughout the package.
#'
#' @return The current DBI connection object.
#' @family connection functions
#' @examples
#' duckr_connect()
#' con <- duckr_con()
#' duckr_close()
#' @export
duckr_con <- function() {
  con <- duckr_get_current()
  if (is.null(con) || !DBI::dbIsValid(con)) {
    cli::cli_abort(c(
      "No active DuckDB connection.",
      "i" = "Open one with {.fn duckr_connect}."
    ))
  }
  con
}

#' Close a DuckDB connection
#'
#' Disconnects and shuts down DuckDB. If the closed connection was the current
#' one, the internal reference is cleared. The console feedback lists the
#' database(s) closed, including any attached catalogs (e.g. PostgreSQL).
#'
#' @param con A DBI connection. Defaults to the current connection.
#'
#' @return `TRUE` if the connection was closed, invisibly.
#' @family connection functions
#' @examples
#' con <- duckr_connect()
#' duckr_close(con)
#' @export
duckr_close <- function(con = duckr_con()) {
  label <- duckr_con_label(con)
  ok <- tryCatch(
    {
      if (DBI::dbIsValid(con)) {
        DBI::dbDisconnect(con, shutdown = TRUE)
      }
      TRUE
    },
    error = function(e) {
      cli::cli_alert_danger("Failed to close connection: {conditionMessage(e)}")
      FALSE
    }
  )

  duckr_remove_current(con)
  if (ok) {
    cli::cli_alert_success("Connection closed: {label}")
  }
  invisible(ok)
}

#' Close all tracked DuckDB connections
#'
#' Closes every connection registered by [duckr_connect()], most recent first
#' (LIFO), and empties the internal stack. Useful when several connections have
#' been opened in a session.
#'
#' @return `TRUE` if all connections closed successfully, invisibly. `TRUE` when
#'   no connection was open.
#' @family connection functions
#' @examples
#' duckr_connect()
#' duckr_connect()
#' duckr_close_all()
#' @export
duckr_close_all <- function() {
  cons <- duckr_list_cons()
  ok <- TRUE
  for (con in rev(cons)) {
    ok <- duckr_close(con) && ok
  }
  invisible(ok)
}
