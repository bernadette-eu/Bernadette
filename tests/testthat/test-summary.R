test_that("'summary' returns an object of class 'table'", {

  data(age_specific_mortality_counts)
  data(age_specific_cusum_infection_counts)

  age_distr    <- age_distribution(country = "Greece", year = 2020)
  lookup_table <- data.frame(Initial = age_distr$AgeGrp,
                             Mapping = c(rep("0-39",  8),
                                         rep("40-64", 5),
                                         rep("65+"  , 3)))

  aggr_age     <- aggregate_age_distribution(age_distr, lookup_table)
  conmat       <- contact_matrix(country = "GRC")
  aggr_cm      <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)
  ifr_mapping  <- c(rep("0-39", 8), rep("40-64", 5), rep("65+", 3))
  aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_cusum_infection_counts)

  ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
                           gamma_mean = 24.19231,
                           gamma_cv   = 0.3987261)

  parallel::detectCores()
  rstan::rstan_options(auto_write = TRUE)

  chains <- 1
  options(mc.cores = chains)

  igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
                        contact_matrix              = aggr_cm,
                        age_distribution_population = aggr_age,
                        age_specific_ifr            = aggr_age_ifr[[3]],
                        itd_distr                   = ditd,
                        incubation_period           = 3,
                        infectious_period           = 4,
                        likelihood_variance_type    = "linear",
                        ecr_changes                 = 7,
                        prior_scale_x0              = 1,
                        prior_scale_x1              = 1,
                        prior_scale_contactmatrix   = 0.05,
                        pi_perc                     = 0.1,
                        prior_volatility            = normal(location = 0, scale = 1),
                        prior_nb_dispersion         = exponential(rate = 1/5),
                        algorithm_inference         = "sampling",
                        nBurn                       = 5,
                        nPost                       = 10,
                        nThin                       = 1,
                        chains                      = chains,
                        adapt_delta                 = 0.80,
                        max_treedepth               = 19,
                        seed                        = 1,
                        refresh = 0)

  print_summary <- summary(object = igbm_fit,
                           y_data = age_specific_mortality_counts)

  expect_equal(class(print_summary)[2], "table")
})
