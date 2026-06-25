test_that("duckr_save_database persists an in-memory database to a file", {
  con <- local_con()
  withr::local_dir(withr::local_tempdir())
  duckr_add_df(mtcars, name = "cars", materialize = TRUE)

  suppressMessages(duckr_save_database("backup.duckdb"))
  expect_identical(file.exists("backup.duckdb"), TRUE)

  con2 <- local_con(dbdir = "backup.duckdb")
  expect_identical(
    DBI::dbGetQuery(con2, "SELECT count(*) AS n FROM cars")$n,
    as.double(nrow(mtcars))
  )
})

test_that("duckr_save_database warns and skips for a file-backed database", {
  withr::local_dir(withr::local_tempdir())
  con <- local_con(dbdir = "live.duckdb")

  expect_warning(
    duckr_save_database("backup.duckdb"),
    "already stored"
  )
  expect_identical(file.exists("backup.duckdb"), FALSE)
})

test_that("duckr_save_database warns about non-materialised views", {
  con <- local_con()
  withr::local_dir(withr::local_tempdir())
  duckr_add_df(mtcars, name = "cars", materialize = TRUE)
  DBI::dbExecute(con, "CREATE VIEW cars_view AS SELECT * FROM cars")

  expect_warning(
    suppressMessages(duckr_save_database("backup.duckdb")),
    "cars_view"
  )
})

test_that("duckr_save_database honours overwrite", {
  con <- local_con()
  withr::local_dir(withr::local_tempdir())
  duckr_add_df(mtcars, name = "cars", materialize = TRUE)
  file.create("backup.duckdb")

  expect_snapshot(duckr_save_database("backup.duckdb"), error = TRUE)
  suppressMessages(duckr_save_database("backup.duckdb", overwrite = TRUE))
  expect_identical(file.exists("backup.duckdb"), TRUE)
})
