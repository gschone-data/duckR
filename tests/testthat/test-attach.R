test_that("duckr_attach_sql builds a safe ATTACH statement", {
  con <- local_con()
  expect_identical(
    duckr_attach_sql(con, "host=localhost dbname=prod", "pg", read_only = TRUE),
    "ATTACH 'host=localhost dbname=prod' AS pg (TYPE postgres, READ_ONLY)"
  )
  expect_identical(
    duckr_attach_sql(con, "host=localhost", "pg", read_only = FALSE),
    "ATTACH 'host=localhost' AS pg (TYPE postgres)"
  )
})

test_that("duckr_attach_sql quotes a reserved alias", {
  con <- local_con()
  expect_match(
    duckr_attach_sql(con, "host=localhost", "select", read_only = TRUE),
    "AS \"select\" "
  )
})

test_that("the postgres extension can be loaded", {
  skip_on_cran()
  con <- local_con()
  ok <- tryCatch(
    {
      DBI::dbExecute(con, "INSTALL postgres")
      DBI::dbExecute(con, "LOAD postgres")
      TRUE
    },
    error = function(e) FALSE
  )
  skip_if_not(ok, "postgres extension unavailable (offline?)")
  expect_true(ok)
})
