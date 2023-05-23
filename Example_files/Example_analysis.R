lib <- c("stats",
         "ggplot2",
         "rstan",
         "bayesplot",
         "Bernadette",
         "loo")
lapply(lib, require, character.only = TRUE)

# Age-specific mortality/incidence count time series:
data(age_specific_mortality_counts)
data(age_specific_infection_counts)

max(age_specific_mortality_counts$Date)

# Import the age distribution for a country in a given year:
age_distr <- age_distribution(country = "Greece", year = 2020)

# Lookup table:
lookup_table <- data.frame(Initial = age_distr$AgeGrp,
                           Mapping = c(rep("0-39",  8),
                                       rep("40-64", 5),
                                       rep("65+"  , 3)))

# Aggregate the age distribution table:
aggr_age <- aggregate_age_distribution(age_distr, lookup_table)

# Import the projected contact matrix for a country (i.e. Greece):
conmat <- contact_matrix(country = "GRC")

# Aggregate the contact matrix:
aggr_cm <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)

# Aggregate the IFR:
ifr_mapping <- c(rep("0-39", 8), rep("40-64", 5), rep("65+", 3))

aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_infection_counts)

# Infection-to-death distribution:
ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
                         gamma_mean = 24.19231,
                         gamma_cv   = 0.3987261)

# Here we sample from four Markov chains in parallel:
parallel::detectCores()
rstan_options(auto_write = TRUE)

chains <- 3

options(mc.cores = chains)

# Posterior sampling:
igbm_fit_init <- stan_igbm(y_data                      = age_specific_mortality_counts,
                      contact_matrix              = aggr_cm,
                      age_distribution_population = aggr_age,
                      age_specific_ifr            = aggr_age_ifr[[3]],
                      itd_distr                   = ditd,
                      incubation_period           = 3,
                      infectious_period           = 4,
                      likelihood_variance_type    = "linear",
                      prior_scale_x0              = 5,
                      prior_scale_contactmatrix   = 0.05,
                      pi_perc                     = 0.1,
                      prior_volatility            = normal(location = 0, scale = 4),
                      prior_nb_dispersion         = exponential(rate = 1/5),
                      algorithm_inference         = "optimizing",
                      seed                        = 1
                      )

sampler_init <- function(){
  list(eta0        = igbm_fit_init$par[names(igbm_fit_init$par) %in% "eta0"],
       eta_init    = igbm_fit_init$par[grepl("eta_init",   names(igbm_fit_init$par), fixed = TRUE)],
       eta_noise   = igbm_fit_init$par[grepl("eta_noise[", names(igbm_fit_init$par), fixed = TRUE)],
       L_raw       = igbm_fit_init$par[grepl("L_raw[",     names(igbm_fit_init$par), fixed = TRUE)],
       pi          = igbm_fit_init$par[names(igbm_fit_init$par) %in% "pi"],
       sigmaBM     = igbm_fit_init$par[grepl("sigmaBM",  names(igbm_fit_init$par), fixed = TRUE)],
       phiD        = igbm_fit_init$par[names(igbm_fit_init$par) %in% "phiD"]
  )
}# End function

igbm_fit <- stan_igbm(y_data                     = age_specific_mortality_counts,
                     contact_matrix              = aggr_cm,
                     age_distribution_population = aggr_age,
                     age_specific_ifr            = aggr_age_ifr[[3]],
                     itd_distr                   = ditd,
                     incubation_period           = 3,
                     infectious_period           = 4,
                     likelihood_variance_type    = "linear",
                     prior_scale_x0              = 5,
                     prior_scale_contactmatrix   = 0.05,
                     pi_perc                     = 0.1,
                     prior_volatility            = normal(location = 0, scale = 4),
                     prior_nb_dispersion         = exponential(rate = 1/5),
                     algorithm_inference         = "sampling",
                     nBurn                       = 10,
                     nPost                       = 20,
                     nThin                       = 1,
                     chains                      = chains,
                     adapt_delta                 = 0.8,
                     max_treedepth               = 14,
                     seed                        = 1,
                     init                        = sampler_init)

# Show only 10% and 90% posterior estimates:
print_summary <- summary(object = igbm_fit,
                         y_data = age_specific_mortality_counts,
                         probs = c(0.1, 0.9))
round(print_summary$summary, 3)

# Example - Pairs plots between some parameters:
cov_data       <- list()
cov_data$A     <- ncol(age_specific_mortality_counts[,-c(1:5)])
cov_data$n_obs <- nrow(age_specific_mortality_counts)

volatilities_names <- paste0("volatilities","[", 1:cov_data$A,"]")

mod1_diagnostics   <- rstan::get_sampler_params(igbm_fit)
posts_1            <- rstan::extract(igbm_fit)           # Posterior draws
lp_cp              <- bayesplot::log_posterior(igbm_fit)
np_cp              <- bayesplot::nuts_params(igbm_fit)
posterior_1        <- as.array(igbm_fit)

bayesplot::mcmc_pairs(posterior_1,
                      pars          = volatilities_names,
                      off_diag_args = list(size = 1.5))

plot_posterior_cm(igbm_fit, y_data = age_specific_mortality_counts)

 post_inf_summary <- posterior_infections(object = igbm_fit,
                                          y_data = age_specific_mortality_counts)

 # Visualise the posterior distribution of the infection counts:
 plot_posterior_infections(post_inf_summary, type = "age-specific")
 plot_posterior_infections(post_inf_summary, type = "aggregated")


  post_mortality_summary <- posterior_mortality(object = igbm_fit,
                                               y_data = age_specific_mortality_counts)

 # Visualise the posterior distribution of the mortality counts:
 plot_posterior_mortality(post_mortality_summary, type = "age-specific")
 plot_posterior_mortality(post_mortality_summary, type = "aggregated")


  post_rt_summary <- posterior_rt(object            = igbm_fit,
                                 y_data            = age_specific_mortality_counts,
                                 age_distribution_population = aggr_age,
                                 infectious_period = 4)

 # Visualise the posterior distribution of the effective reproduction number:
 plot_posterior_rt(post_rt_summary)


  post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
                                                 y_data = age_specific_mortality_counts)

 # Visualise the posterior distribution of the age-specific transmission rate:
 plot_posterior_transmrate(post_transmrate_summary)


 log_lik_1 <- loo::extract_log_lik(igbm_fit, merge_chains = FALSE)
 r_eff_1   <- loo::relative_eff(exp(log_lik_1), cores = 4)

 loo_1 <- loo::loo(log_lik_1, r_eff = r_eff_1, cores = 4)
 print(loo_1)
