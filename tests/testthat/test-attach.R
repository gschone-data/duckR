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

test_that("duckr_warn_pgpass_perms warns on an over-permissive .pgpass", {
  skip_on_os("windows")
  pgpass <- withr::local_tempfile()
  writeLines("localhost:5432:*:reader:secret", pgpass)
  Sys.chmod(pgpass, "666")
  withr::local_envvar(PGPASSFILE = pgpass)
  expect_warning(
    duckr_warn_pgpass_perms("host=localhost dbname=prod user=reader"),
    "ignore it"
  )
})

test_that("duckr_warn_pgpass_perms is silent when safe or password is inline", {
  skip_on_os("windows")
  pgpass <- withr::local_tempfile()
  writeLines("localhost:5432:*:reader:secret", pgpass)
  withr::local_envvar(PGPASSFILE = pgpass)

  Sys.chmod(pgpass, "600")
  expect_no_warning(duckr_warn_pgpass_perms("host=localhost user=reader"))

  Sys.chmod(pgpass, "666")
  expect_no_warning(
    duckr_warn_pgpass_perms("host=localhost user=reader password=x")
  )
})

test_that("duckr_explore skips PostgreSQL system schemas on an attached db", {
  skip_on_cran()
  conn <- Sys.getenv("DUCKR_TEST_PG_CONN", unset = "")
  skip_if(conn == "", "set DUCKR_TEST_PG_CONN to test against PostgreSQL")

  con <- local_con()
  ok <- tryCatch(
    {
      DBI::dbExecute(con, "INSTALL postgres")
      DBI::dbExecute(con, "LOAD postgres")
      DBI::dbExecute(con, duckr_attach_sql(con, conn, "pg", read_only = TRUE))
      TRUE
    },
    error = function(e) FALSE
  )
  skip_if_not(ok, "PostgreSQL server unreachable")

  info <- duckr_explore(con)
  expect_false(any(info$schema %in% c("information_schema", "pg_catalog")))
  expect_false("_pg_foreign_data_wrappers" %in% info$name)
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
