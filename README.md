
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Bernadette <img src="https://github.com/bernadette-eu/bernadette-eu.github.io/blob/9588dba70edb87adc5b026ec0ae1912c290bfeb0/images/abc.png" align="right" height="150px" width="150px"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/bernadette-eu/Bernadette/workflows/R-CMD-check/badge.svg)](https://github.com/bernadette-eu/Bernadette/actions)
[![CRAN
status](https://www.r-pkg.org/badges/version/Bernadette)](https://cran.r-project.org/package=Bernadette)
[![r-universe](https://bernadette-eu.r-universe.dev/badges/Bernadette)](https://Bernadette.r-universe.dev/ui/#package:Bernadette)
[![Last-commit](https://img.shields.io/github/last-commit/bernadette-eu/Bernadette)](https://github.com/bernadette-eu/Bernadette/commits/main)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-green.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![downloads](https://cranlogs.r-pkg.org/badges/Bernadette)](https://shinyus.ipub.com/cranview/)
[![total](https://cranlogs.r-pkg.org/badges/grand-total/Bernadette)](https://shinyus.ipub.com/cranview/)
<!-- badges: end -->

## Overview

The **Bernadette** (“Bayesian inference and model selection for
stochastic epidemics”) R package provides a framework for Bayesian
analysis of infectious disease transmission dynamics via diffusion
driven multi-type epidemic models with time-varying coefficients, with a
particular focus on Coronavirus Disease 2019 (COVID-19). For models fit
using Markov chain Monte Carlo, it allows for computation of approximate
leave-one-out cross-validation (LOO, LOOIC) or the Widely Applicable
Information Criterion (WAIC) using the **loo** package for model
checking and comparison.

## Website

The website for the BERNADETTE Marie Sklodowska-Curie Action (MSCA) is
available at: <https://bernadette-eu.github.io/>.

## Installation

Installation of the package requires you to have a working C++
toolchain. To ensure that this is working, please first install
**rstan** by following these [installation
instructions](https://github.com/stan-dev/rstan/wiki/RStan-Getting-Started)
from the Rstan wiki.

The following must return `TRUE` before continuing:

    if (!require("pkgbuild")) {
      install.packages("pkgbuild")
    }
    pkgbuild::has_build_tools(debug = TRUE)

Having installed **rstan**, you can then install the latest development
version of **Bernadette** (requires the
[devtools](https://github.com/r-lib/devtools) package) from
[GitHub](https://github.com/) with:

``` r
if (!require("devtools")) {
  install.packages("devtools")
}
devtools::install_github("bernadette-eu/Bernadette", dependencies = TRUE, build_vignettes = FALSE)
```

or the latest version on CRAN

``` r
install.packages("Bernadette")
```

## Load any required libraries

``` r
lib <- c("stats",
         "ggplot2",
         "rstan",
         "bayesplot",
         "Bernadette",
         "loo")
lapply(lib, require, character.only = TRUE)
```

## Example - COVID-19 in Greece

The time series of new daily age-specific mortality and incidence counts
are ordered by epidemiological date. The time horizon in the example
datasets for Greece spans from 2020-08-31 to 2021-03-28.

``` r
Sys.setlocale("LC_ALL", "English")
data(age_specific_mortality_counts)
data(age_specific_infection_counts)
```

``` r
sub <- age_specific_mortality_counts[c(3, 6:ncol(age_specific_mortality_counts))]
mortality_df_long <- stats::reshape(sub,
                                    direction = "long",
                                    varying   = list(names(sub)[2:ncol(sub)]),
                                    v.names   = "New_Deaths",
                                    idvar     = c("Date"),
                                    timevar   = "Group",
                                    times     = colnames(sub)[-1])
```

![](README_files/figure-gfm/mortality_time_series-1.png)<!-- -->

Import and plot the age distribution for Greece in 2020:

``` r
age_distr <- age_distribution(country = "Greece", year = 2020)
plot_age_distribution(age_distr)
```

![](README_files/figure-gfm/unnamed-chunk-6-1.png)<!-- -->

Information is available for sixteen 5-year age groups, with the last
one being “75+”. We shall consider three age groups, {0-39, 40-64, 65+},
by providing the following lookup table:

``` r
lookup_table <- data.frame(Initial = age_distr$AgeGrp,
                           Mapping = c(rep("0-39",  8),
                                       rep("40-64", 5),
                                       rep("65+"  , 3)))
aggr_age <- aggregate_age_distribution(age_distr, lookup_table)
plot_age_distribution(aggr_age)
```

![](README_files/figure-gfm/unnamed-chunk-7-1.png)<!-- -->

Next, import the projected contact matrix for Greece:

``` r
conmat <- contact_matrix(country = "GRC")
plot_contact_matrix(conmat)
```

![](README_files/figure-gfm/unnamed-chunk-8-1.png)<!-- -->

Aggregate the contact matrix to the age groups {0-39, 40-64, 65+}:

``` r
aggr_cm <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)
plot_contact_matrix(aggr_cm)
```

![](README_files/figure-gfm/unnamed-chunk-9-1.png)<!-- -->

Obtain estimates of the age-specific infection-fatality-ratio:

``` r
ifr_mapping <- c(rep("0-39", 8), rep("40-64", 5), rep("65+", 3))
aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_infection_counts)
```

Provide the infection-to-death distribution with a mean of 24.19 days:

``` r
ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
                         gamma_mean = 24.19231,
                         gamma_cv   = 0.3987261)
```

Before performing MCMC, we can execute the routine for maximizing the
joint posterior from the model. The estimates can be used as
initialization points for the HMC algorithm.

``` r
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
```

    ## Warning in .local(object, ...): non-zero return code in optimizing

    ## Error in chol.default(-H) : 
    ##   the leading minor of order 1 is not positive definite

``` r
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
```

Find the number of cores in your machine and indicate how many will be
used for parallel processing:

``` r
parallel::detectCores()
rstan_options(auto_write = TRUE)

# Here we sample from four Markov chains in parallel:
chains <- 6

options(mc.cores = chains)
```

Sample from the posterior distribution of the parameters using the
Hamiltonian Monte Carlo algorithm implemented in Stan - Note that a
longer time horizon and/or a greater number of age groups in `y_data`
will lead to increased CPU time:

``` r
igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
                      contact_matrix              = aggr_cm,
                      age_distribution_population = aggr_age,
                      age_specific_ifr            = aggr_age_ifr[[3]],
                      itd_distr                   = ditd,
                      likelihood_variance_type    = "quadratic",
                      prior_volatility            = normal(location = 0, scale = 1),
                      prior_nb_dispersion         = gamma(shape = 2, rate = 1),
                      algorithm_inference         = "sampling",
                      nBurn                       = 500,
                      nPost                       = 500,
                      nThin                       = 1,
                      chains                      = chains,
                      adapt_delta                 = 0.8,
                      max_treedepth               = 14,
                      seed                        = 1,
                      init                        = sampler_init)
```

## Summarise the distributions of estimated parameters and derived quantities using the posterior draws.

``` r
print_summary <- summary(object = igbm_fit,
                         y_data = age_specific_mortality_counts)
round(print_summary$summary, 3)
```

## MCMC diagnostic plots

Example - Pairs plots between some parameters:

``` r
volatilities_names <- paste0("volatilities","[", 1:ncol(age_specific_mortality_counts[,-c(1:5)]),"]")
posterior_1        <- as.array(igbm_fit)
```

``` r
bayesplot::mcmc_pairs(posterior_1,
                      pars          = volatilities_names,
                      off_diag_args = list(size = 1.5))
```

## Plot the posterior estimates of epidemiological quantities

Visualise the posterior distribution of the random contact matrix:

``` r
plot_posterior_cm(igbm_fit, y_data = age_specific_mortality_counts)
```

Visualise the posterior distribution (age-specific or aggregated daily
estimates) of the infection counts:

``` r
post_inf_summary <- posterior_infections(object = igbm_fit,
                                         y_data = age_specific_mortality_counts)
```

``` r
plot_posterior_infections(post_inf_summary, type = "age-specific")
```

``` r
plot_posterior_infections(post_inf_summary, type = "aggregated")
```

Visualise the posterior distribution (age-specific or aggregated daily
estimates) of the mortality counts:

``` r
post_mortality_summary <- posterior_mortality(object = igbm_fit,
                                              y_data = age_specific_mortality_counts)
```

``` r
plot_posterior_mortality(post_mortality_summary, type = "age-specific")
```

``` r
plot_posterior_mortality(post_mortality_summary, type = "aggregated")
```

Visualise the posterior distribution of the effective reproduction
number:

``` r
post_rt_summary <- posterior_rt(object                      = igbm_fit,
                                y_data                      = age_specific_mortality_counts,
                                age_distribution_population = aggr_age,
                                infectious_period           = 4)
plot_posterior_rt(post_rt_summary)
```

Visualise the posterior distribution of the age-specific transmission
rate:

``` r
post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
                                                y_data = age_specific_mortality_counts)
plot_posterior_transmrate(post_transmrate_summary)
```

## Model checking and comparison with loo

For more information about the **loo** package visit the [dedicated
website](https://mc-stan.org/loo/).

``` r
# (for bigger models use as many cores as possible)
log_lik_1 <- loo::extract_log_lik(igbm_fit, merge_chains = FALSE)
r_eff_1   <- loo::relative_eff(exp(log_lik_1), cores = 4)
```

The estimated LOO Information Criterion and the respective estimated
effective number of parameters are given by

``` r
loo_1 <- loo::loo(log_lik_1, r_eff = r_eff_1, cores = 4)
print(loo_1)
```

The estimated Widely Applicable Information Criterion and the respective
estimated effective number of parameters are given by

``` r
waic_1 <- loo::waic(log_lik_1)
print(waic_1)
```

## License

This R package is provided for use under the GPL-3.0 License by the
author.

## Contributing

File an issue [here](https://github.com/bernadette-eu/Bernadette/issues)
if you have identified an issue with the package. We welcome all
contributions, in particular those that improve the approach or the
robustness of the code base. We also welcome additions and extensions to
the underlying model either in the form of options or improvements.
