# duckr_add_csv errors when the object exists

    Code
      duckr_add_csv("t.csv", dir = dir, name = "t")
    Condition
      Error in `duckr_drop_if_exists()`:
      ! An object named "t" already exists.
      i Use `overwrite = TRUE` to replace it.

# duckr_add_df errors when the object exists

    Code
      duckr_add_df(iris, name = "iris_v")
    Condition
      Error in `duckr_drop_if_exists()`:
      ! An object named "iris_v" already exists.
      i Use `overwrite = TRUE` to replace it.

# duckr_add_lazy rejects a query from another connection

    Code
      duckr_add_lazy(lazy, name = "x", con = con)
    Condition
      Error in `duckr_add_lazy()`:
      ! `lazy` must be built on the same connection as `con`.
      i Rebuild the query with `dplyr::tbl(con, ...)`.

