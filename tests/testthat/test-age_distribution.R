test_that("'age_distribution' returns a data.frame with 16 rows", {
  t1 <- age_distribution(country = "Greece", year = 2020)
  expect_rows(t1)
})
