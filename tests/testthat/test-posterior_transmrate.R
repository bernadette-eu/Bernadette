test_that(" The number of dates returned by 'posterior_transmrate' is correct.", {

  data(age_specific_mortality_counts)

  giturl <- "https://github.com/bernadette-eu/Bernadette/blob/master/Example_files/Experiment_v112.RData?raw=true"
  load(url(giturl))

  post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
                                                  y_data = age_specific_mortality_counts)

  expect_equal(length(unique(post_transmrate_summary$Date)) , nrow(age_specific_mortality_counts))
})
