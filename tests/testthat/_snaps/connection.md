# duckr_connect falls back when RAM is undetectable

    Code
      con <- duckr_connect()
    Condition
      Warning:
      Could not detect total RAM.
      i Keeping DuckDB's default memory limit.
    Message
      v Connected to DuckDB (":memory:") | memory: DuckDB default | threads: all cores
    Code
      duckr_close(con)
    Message
      v Connection closed: memory (:memory:)

# duckr_con errors when no connection is active

    Code
      duckr_con()
    Condition
      Error in `duckr_con()`:
      ! No active DuckDB connection.
      i Open one with `duckr_connect()`.

