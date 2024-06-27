# Bernadette 1.1.6

### Bug fixes
* Debugged the function R/aggregate_contact_matrix.R, to return the age group labels in the correct order in the row names & column names of the contact matrix.

# Bernadette 1.1.5

* Improved the description field of the help file for R/priors.R and stated what the default values are in the help comments of the function 'handle_prior'.
* Add a comment in R/globals.R aimed at users  who are not familiar with Global Variables or are doing something that conflicts with these names.

# Bernadette 1.1.4

### New features

* The end-user is enabled to change the granularity of the effective contact rate within a time-span of seven days.

# Bernadette 1.1.3

### Bug fixes

* Function R/stan_igbm.fit.R: removed code line 'out$stanfit <- suppressMessages(rstan::sampling(stanfit, data = standata, chains = 0))'.
* Functions R/posterior_.R: added a stopping rule that tries to locate "theta_tilde" in 'names(object)', which can only be found in the object returned by rstan::optimizing(). A message is shown, instructing the user to perform Markov chain Monte Carlo sampling using rstan::sampling() or rstan::vb().

# Bernadette 1.1.2

### Bug fixes

* Debugged functions R/stan_igbm.fit.R, R/stan_igbm.R and R/summary.stangbm.R.
* Debugged the R/posterior_.R functions.

# Bernadette 1.1.1

* Released to CRAN on 2023-05-18
