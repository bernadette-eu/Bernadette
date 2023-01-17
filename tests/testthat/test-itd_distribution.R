test_that("Function throws an error if all parameters are set to NULL", {
  expect_error(
    itd_distribution(100,
                    gamma_mean = NULL,
                    gamma_cv   = NULL,
                    gamma_shape= NULL,
                    gamma_rate = NULL)
  )
})
