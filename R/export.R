#' Export a table or view to a Parquet file
#'
#' Copies the content of a table or view of the connection to a Parquet file.
#'
#' @param name Name of the table or view to export.
#' @param file Output Parquet file name.
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
#' duckr_to_parquet("cars", "cars.parquet", dir = tempdir())
#' duckr_close()
#' @export
duckr_to_parquet <- function(
  name,
  file,
  dir = ".",
  con = duckr_con(),
  overwrite = FALSE
) {
  duckr_copy_to(con, name, file.path(dir, file), "FORMAT parquet", overwrite)
}

#' Export a table or view to a CSV file
#'
#' Copies the content of a table or view of the connection to a CSV file.
#'
#' @param name Name of the table or view to export.
#' @param file Output CSV file name.
#' @param dir Directory to write `file` into. Defaults to `"."`.
#' @param con A DBI connection. Defaults to the current connection.
#' @param delim Field delimiter. `NULL` (default) uses DuckDB's default (`,`); a
#'   string forces the delimiter.
#' @param header Whether to write a header row. Defaults to `TRUE`.
#' @param overwrite If `FALSE` (default) error when the output file exists; if
#'   `TRUE` overwrite it.
#'
#' @return The connection `con`, invisibly.
#' @family data exporters
#' @examples
#' con <- duckr_connect()
#' duckr_add_df(mtcars, name = "cars")
#' duckr_to_csv("cars", "cars.csv", dir = tempdir())
#' duckr_close()
#' @export
duckr_to_csv <- function(
  name,
  file,
  dir = ".",
  con = duckr_con(),
  delim = NULL,
  header = TRUE,
  overwrite = FALSE
) {
  opts <- paste0("FORMAT csv, HEADER ", if (isTRUE(header)) "true" else "false")
  if (!is.null(delim)) {
    opts <- paste0(opts, ", DELIMITER ", DBI::dbQuoteString(con, delim))
  }
  duckr_copy_to(con, name, file.path(dir, file), opts, overwrite)
}
