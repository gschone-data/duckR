# duckr_save_database honours overwrite

    Code
      duckr_save_database("backup.duckdb")
    Condition
      Error in `duckr_check_out_file()`:
      ! A file already exists at './backup.duckdb'.
      i Use `overwrite = TRUE` to replace it.

