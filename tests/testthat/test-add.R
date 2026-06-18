test_that("duckr_add_csv creates a view then a materialised table", {
  con <- local_con()
  dir <- withr::local_tempdir()
  write.csv(
    data.frame(a = 1:3, b = c("x", "y", "z")),
    file.path(dir, "t.csv"),
    row.names = FALSE
  )

  suppressMessages(duckr_add_csv("t.csv", dir = dir, name = "t"))
  info <- duckr_explore(con)
  expect_identical(info$type[info$name == "t"], "view")
  expect_identical(info$n_rows[info$name == "t"], 3)

  suppressMessages(duckr_add_csv(
    "t.csv",
    dir = dir,
    name = "t",
    materialize = TRUE,
    overwrite = TRUE
  ))
  info <- duckr_explore(con)
  expect_identical(info$type[info$name == "t"], "table")
})

test_that("duckr_add_csv honours delim and header", {
  con <- local_con()
  dir <- withr::local_tempdir()
  writeLines(c("a;b", "1;x", "2;y"), file.path(dir, "semi.csv"))

  suppressMessages(duckr_add_csv(
    "semi.csv",
    dir = dir,
    name = "delimited",
    delim = ";"
  ))
  expect_identical(
    names(DBI::dbGetQuery(con, "SELECT * FROM delimited")),
    c("a", "b")
  )

  suppressMessages(duckr_add_csv(
    "semi.csv",
    dir = dir,
    name = "noheader",
    delim = ";",
    header = FALSE
  ))
  cols <- names(DBI::dbGetQuery(con, "SELECT * FROM noheader"))
  expect_identical(cols, c("column0", "column1"))
})

test_that("duckr_add_csv errors when the object exists", {
  con <- local_con()
  dir <- withr::local_tempdir()
  write.csv(data.frame(a = 1), file.path(dir, "t.csv"), row.names = FALSE)
  suppressMessages(duckr_add_csv("t.csv", dir = dir, name = "t"))
  expect_snapshot(
    duckr_add_csv("t.csv", dir = dir, name = "t"),
    error = TRUE
  )
})

test_that("duckr_add_parquet creates an object", {
  con <- local_con()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "t.parquet")
  DBI::dbExecute(
    con,
    sprintf(
      "COPY (SELECT 1 AS a UNION ALL SELECT 2) TO '%s' (FORMAT parquet)",
      path
    )
  )

  suppressMessages(duckr_add_parquet("t.parquet", dir = dir, name = "p"))
  expect_identical(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM p")$n, 2)
})

test_that("duckr_add_lazy creates an object from a dbplyr query", {
  con <- local_con()
  DBI::dbExecute(con, "CREATE TABLE src AS SELECT 'N' AS region, 10 AS v")
  lazy <- dplyr::summarise(
    dplyr::group_by(dplyr::tbl(con, "src"), region),
    total = sum(v, na.rm = TRUE)
  )
  suppressMessages(duckr_add_lazy(lazy, name = "agg", materialize = TRUE))
  expect_identical(DBI::dbGetQuery(con, "SELECT total FROM agg")$total, 10)
})

test_that("duckr_add_df adds iris as a view then a materialised table", {
  con <- local_con()

  suppressMessages(duckr_add_df(iris, name = "iris_v"))
  info <- duckr_explore(con)
  expect_identical(info$type[info$name == "iris_v"], "view")
  expect_identical(info$n_rows[info$name == "iris_v"], 150)

  suppressMessages(duckr_add_df(
    iris,
    name = "iris_v",
    materialize = TRUE,
    overwrite = TRUE
  ))
  info <- duckr_explore(con)
  expect_identical(info$type[info$name == "iris_v"], "table")
  expect_identical(info$n_rows[info$name == "iris_v"], 150)
})

test_that("duckr_add_df errors when the object exists", {
  con <- local_con()
  suppressMessages(duckr_add_df(iris, name = "iris_v"))
  expect_snapshot(duckr_add_df(iris, name = "iris_v"), error = TRUE)
})

test_that("duckr_add_lazy rejects a query from another connection", {
  con <- local_con()
  con2 <- local_con()
  DBI::dbExecute(con2, "CREATE TABLE src AS SELECT 1 AS v")
  lazy <- dplyr::tbl(con2, "src")
  expect_snapshot(
    duckr_add_lazy(lazy, name = "x", con = con),
    error = TRUE
  )
})
