test_that("duckr_explore lists tables and views with row counts", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE TABLE t1 AS SELECT 1 AS x UNION ALL SELECT 2")
  DBI::dbExecute(con, "CREATE VIEW v1 AS SELECT * FROM t1")

  info <- duckr_explore(con)
  expect_setequal(info$name, c("t1", "v1"))
  expect_identical(info$type[info$name == "v1"], "view")
  expect_identical(info$n_rows[info$name == "t1"], 2)
})

test_that("duckr_explore skips row counts when row_count = FALSE", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE TABLE t1 AS SELECT 1 AS x")
  info <- duckr_explore(con, row_count = FALSE)
  expect_true(all(is.na(info$n_rows)))
})

test_that("duckr_status reports the expected fields", {
  con <- local_con()
  status <- duckr_status(con)
  expect_named(
    status,
    c(
      "database",
      "type",
      "memory_limit",
      "memory_used",
      "threads",
      "n_objects",
      "duckdb_version"
    )
  )
  expect_identical(status$type, "memory")
  expect_match(status$duckdb_version, "^v")
})
