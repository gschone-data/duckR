test_that("duckr_connect opens and registers the current connection", {
  con <- local_con()
  expect_true(DBI::dbIsValid(con))
  expect_identical(duckr_con(), con)
  limit <- DBI::dbGetQuery(con, "SELECT current_setting('memory_limit') AS m")$m
  expect_true(nzchar(limit))
})

test_that("duckr_connect caps threads when requested", {
  con <- local_con(threads = 2)
  threads <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS t")$t
  expect_identical(as.integer(threads), 2L)
})

test_that("duckr_connect falls back when RAM is undetectable", {
  local_mocked_bindings(duckr_total_ram = function() NA_real_)
  expect_snapshot({
    con <- duckr_connect()
    duckr_close(con)
  })
})

test_that("duckr_con errors when no connection is active", {
  duckr_clear_current()
  expect_snapshot(duckr_con(), error = TRUE)
})

test_that("duckr_close clears the current connection and is robust", {
  con <- suppressMessages(duckr_connect())
  expect_true(suppressMessages(duckr_close(con)))
  expect_null(duckr_get_current())
  expect_true(suppressMessages(duckr_close(con)))
})

test_that("duckr_close walks the connection stack (LIFO)", {
  duckr_clear_current()
  c1 <- suppressMessages(duckr_connect())
  c2 <- suppressMessages(duckr_connect())
  expect_identical(duckr_con(), c2)
  expect_true(suppressMessages(duckr_close()))
  expect_false(DBI::dbIsValid(c2))
  expect_identical(duckr_con(), c1)
  expect_true(suppressMessages(duckr_close()))
  expect_false(DBI::dbIsValid(c1))
  expect_null(duckr_get_current())
})

test_that("duckr_close_all closes every tracked connection", {
  duckr_clear_current()
  c1 <- suppressMessages(duckr_connect())
  c2 <- suppressMessages(duckr_connect())
  expect_true(suppressMessages(duckr_close_all()))
  expect_false(DBI::dbIsValid(c1))
  expect_false(DBI::dbIsValid(c2))
  expect_null(duckr_get_current())
})
