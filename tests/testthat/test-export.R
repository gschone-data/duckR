test_that("duckr_to_parquet exports a table that reloads identically", {
  con <- local_con()
  dir <- withr::local_tempdir()
  DBI::dbExecute(con, "CREATE TABLE t AS SELECT 1 AS a UNION ALL SELECT 2")

  suppressMessages(duckr_to_parquet("t", file = "t.parquet", dir = dir))
  expect_identical(file.exists(file.path(dir, "t.parquet")), TRUE)

  suppressMessages(duckr_add_parquet("t.parquet", dir = dir, name = "back"))
  expect_identical(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM back")$n, 2)
})

test_that("duckr_to_csv honours delim and header on reload", {
  con <- local_con()
  dir <- withr::local_tempdir()
  DBI::dbExecute(con, "CREATE TABLE t AS SELECT 1 AS a, 'x' AS b")

  suppressMessages(duckr_to_csv("t", file = "t.csv", dir = dir, delim = ";"))
  suppressMessages(duckr_add_csv(
    "t.csv",
    dir = dir,
    name = "back",
    delim = ";"
  ))
  back <- DBI::dbGetQuery(con, "SELECT * FROM back")
  expect_identical(names(back), c("a", "b"))
  expect_identical(nrow(back), 1L)
})

test_that("roundtrip parquet on the penguins fixture", {
  con <- local_con()
  csv_dir <- system.file("extdata", package = "duckR")
  tmp <- withr::local_tempdir()

  suppressMessages(duckr_add_csv(
    "penguins.csv",
    dir = csv_dir,
    name = "penguins"
  ))
  suppressMessages(duckr_to_parquet("penguins", "penguins.parquet", dir = tmp))
  suppressMessages(duckr_add_parquet(
    "penguins.parquet",
    dir = tmp,
    name = "pq"
  ))

  n <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM penguins")$n
  expect_identical(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM pq")$n, n)
})

test_that("duckr_to_parquet errors when the file exists", {
  con <- local_con()
  withr::local_dir(withr::local_tempdir())
  DBI::dbExecute(con, "CREATE TABLE t AS SELECT 1 AS a")
  suppressMessages(duckr_to_parquet("t", file = "t.parquet"))
  expect_snapshot(duckr_to_parquet("t", file = "t.parquet"), error = TRUE)
})
