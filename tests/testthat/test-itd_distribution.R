test_that("'itd_distribution' returns an object whose length agrees with the number of rows of the age-specific time series", {

  data(age_specific_mortality_counts)

  ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
                           gamma_mean = 24.19231,
                           gamma_cv   = 0.3987261)

  expect_equal(length(ditd), nrow(age_specific_mortality_counts))
})
