test_that("duckr_explore lists tables and views with row counts", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE TABLE t1 AS SELECT 1 AS x UNION ALL SELECT 2")
  DBI::dbExecute(con, "CREATE VIEW v1 AS SELECT * FROM t1")

  info <- duckr_explore(con)
  expect_setequal(info$name, c("t1", "v1"))
  expect_identical(info$type[info$name == "v1"], "view")
  expect_identical(info$n_rows[info$name == "t1"], 2)
})

test_that("duckr_explore lists objects in non-default user schemas", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE SCHEMA s1")
  DBI::dbExecute(con, "CREATE TABLE s1.t AS SELECT 1 AS x")
  info <- duckr_explore(con, row_count = FALSE)
  expect_true("t" %in% info$name)
  expect_identical(info$schema[info$name == "t"], "s1")
})

test_that("duckr_explore skips row counts when row_count = FALSE", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE TABLE t1 AS SELECT 1 AS x")
  info <- duckr_explore(con, row_count = FALSE)
  expect_true(all(is.na(info$n_rows)))
})

test_that("duckr_explore handles a connection with no objects", {
  con <- local_con()
  info <- duckr_explore(con)
  expect_identical(nrow(info), 0L)
  expect_named(info, c("catalog", "schema", "name", "type", "n_rows"))
  expect_identical(nrow(duckr_explore(con, row_count = FALSE)), 0L)
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
