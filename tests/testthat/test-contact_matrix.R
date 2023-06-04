test_that("'contact_matrix' returns a data.frame with 16 rows", {
  conmat <- contact_matrix(country = "GRC")
  expect_rows(conmat)
})
