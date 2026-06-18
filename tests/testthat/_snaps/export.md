# duckr_to_parquet errors when the file exists

    Code
      duckr_to_parquet("t", file = "t.parquet")
    Condition
      Error in `duckr_check_out_file()`:
      ! A file already exists at './t.parquet'.
      i Use `overwrite = TRUE` to replace it.

