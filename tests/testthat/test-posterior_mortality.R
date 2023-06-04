test_that("'posterior_infections' returns an list of length 2.", {

  data(age_specific_mortality_counts)

  giturl <- "https://github.com/bernadette-eu/Bernadette/blob/master/Example_files/Experiment_v112.RData?raw=true"
  load(url(giturl))

  post_mortality_summary <- posterior_mortality(object = igbm_fit,
                                                y_data = age_specific_mortality_counts)

  expect_equal(length(post_mortality_summary), 2)
})
