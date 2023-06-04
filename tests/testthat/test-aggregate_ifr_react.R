test_that("'aggregate_ifr_react' returns a list of length 3", {

  data(age_specific_cusum_infection_counts)
  ifr_mapping  <- c(rep("0-39", 8), rep("40-64", 5), rep("65+", 3))
  aggr_age_ifr <- aggregate_ifr_react(age_distr,
                                      ifr_mapping,
                                      age_specific_cusum_infection_counts)

  expect_equal(length(aggr_age_ifr), 3)
})
