test_that("'aggregate_ifr_react' returns a list of length 3", {

  age_distr    <- age_distribution(country = "Greece", year = 2020)
  lookup_table <- data.frame(Initial = age_distr$AgeGrp,
                             Mapping = c(rep("0-39",  8),
                                         rep("40-64", 5),
                                         rep("65+"  , 3)))

  aggr_age <- aggregate_age_distribution(age_distr, lookup_table)
  aggr_cm  <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)

  expect_agrr_rows(aggr_cm, lookup_table)
})
