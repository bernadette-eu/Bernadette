test_that("'aggregate_age_distribution' returns the correct number of rows", {

  age_distr <- age_distribution(country = "Greece", year = 2020)

  #---- Lookup table:
  lookup_table <- data.frame(Initial = age_distr$AgeGrp,
                             Mapping = c(rep("0-39",  8),
                                         rep("40-64", 5),
                                         rep("65+"  , 3)))



  #---- Aggregate the age distribution table:
  aggr_age <- aggregate_age_distribution(age_distr, lookup_table)

  expect_agrr_rows(aggr_age, lookup_table)
})
