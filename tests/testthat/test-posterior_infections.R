test_that("'posterior_infections' returns an list of length 2.", {

  data(age_specific_mortality_counts)

  giturl <- "https://github.com/bernadette-eu/Bernadette/blob/master/Example_files/Experiment_v112.RData?raw=true"
  load(url(giturl))

  post_inf_summary <- posterior_infections(object = igbm_fit,
                                           y_data = age_specific_mortality_counts)

  expect_equal(length(post_inf_summary), 2)
})
