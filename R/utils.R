# Internal environment holding the "current" DuckDB connection.
.duckr_env <- new.env(parent = emptyenv())

duckr_set_current <- function(con) {
  assign("con", con, envir = .duckr_env)
}

duckr_get_current <- function() {
  if (exists("con", envir = .duckr_env, inherits = FALSE)) {
    get("con", envir = .duckr_env)
  } else {
    NULL
  }
}

duckr_clear_current <- function() {
  if (exists("con", envir = .duckr_env, inherits = FALSE)) {
    rm("con", envir = .duckr_env)
  }
}

# Total physical RAM in bytes, multiplatform and dependency-free.
# Returns NA_real_ when detection fails.
duckr_total_ram <- function() {
  bytes <- tryCatch(
    switch(
      Sys.info()[["sysname"]],
      Linux = {
        line <- grep("^MemTotal:", readLines("/proc/meminfo"), value = TRUE)
        as.numeric(gsub("[^0-9]", "", line)) * 1024
      },
      Darwin = as.numeric(system2(
        "sysctl",
        c("-n", "hw.memsize"),
        stdout = TRUE
      )),
      Windows = as.numeric(system2(
        "powershell",
        c(
          "-NoProfile",
          "-Command",
          "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"
        ),
        stdout = TRUE
      )),
      NA_real_
    ),
    error = function(e) NA_real_
  )
  if (length(bytes) != 1L || is.na(bytes) || bytes <= 0) NA_real_ else bytes
}

# Format a byte count into an absolute memory_limit string DuckDB accepts.
duckr_format_memory <- function(bytes) {
  mb <- floor(bytes / 1e6)
  if (mb >= 1000) paste0(floor(mb / 1000), "GB") else paste0(mb, "MB")
}

# Build and run a CREATE {VIEW|TABLE} "name" AS <select_sql>.
# Errors (cli) when the object exists and overwrite = FALSE; when overwrite is
# TRUE the existing object is dropped first (handles a view/table type switch).
# Returns the object type ("view" or "table").
duckr_create_as <- function(con, name, select_sql, materialize, overwrite) {
  existing <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT table_type FROM information_schema.tables WHERE table_name = ",
      DBI::dbQuoteString(con, name),
      " LIMIT 1"
    )
  )
  if (nrow(existing) > 0L) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(c(
        "An object named {.val {name}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it."
      ))
    }
    # CREATE OR REPLACE cannot switch a view to a table (or vice versa), so
    # drop the existing object first.
    drop_kw <- if (existing$table_type == "VIEW") "VIEW" else "TABLE"
    DBI::dbExecute(
      con,
      paste0(
        "DROP ",
        drop_kw,
        " IF EXISTS ",
        DBI::dbQuoteIdentifier(con, name)
      )
    )
  }

  type <- if (isTRUE(materialize)) "TABLE" else "VIEW"
  DBI::dbExecute(
    con,
    paste0(
      "CREATE ",
      type,
      " ",
      DBI::dbQuoteIdentifier(con, name),
      " AS ",
      select_sql
    )
  )
  tolower(type)
}
