# duckr_add_csv errors when the object exists

    Code
      duckr_add_csv("t.csv", dir = dir, name = "t")
    Condition
      Error in `duckr_create_as()`:
      ! An object named "t" already exists.
      i Use `overwrite = TRUE` to replace it.

# duckr_add_lazy rejects a query from another connection

    Code
      duckr_add_lazy(lazy, name = "x", con = con)
    Condition
      Error in `duckr_add_lazy()`:
      ! `lazy` must be built on the same connection as `con`.
      i Rebuild the query with `dplyr::tbl(con, ...)`.

