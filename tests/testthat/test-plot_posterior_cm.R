test_that("'plot_posterior_cm' returns an object of class 'gtable'.", {

  data(age_specific_mortality_counts)

  giturl <- "https://github.com/bernadette-eu/Bernadette/blob/master/Example_files/Experiment_v112.RData?raw=true"
  load(url(giturl))

  t1 <- plot_posterior_cm(igbm_fit, y_data = age_specific_mortality_counts)

  expect_equal(class(t1)[1], "gtable")
})
