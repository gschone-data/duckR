test_that("package can be loaded", {
  expect_identical(utils::packageDescription("duckR")$Package, "duckR")
})
