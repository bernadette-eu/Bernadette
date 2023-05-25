
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

NOTE: This documentation is work in progress.

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
datasets for Greece spans from 2020-08-31 to 2021-03-28 (210 days).

``` r
Sys.setlocale("LC_ALL", "English")
data(age_specific_mortality_counts)
data(age_specific_infection_counts)
```

![](README_files/figure-gfm/mortality_time_series-1.png)<!-- -->

The model described below can be computationally expensive to implement
and so we restrict the analysis to a shorter time horizon. We analyse
the subset from 2020-10-02 to 2021-01-07 (98 days):

``` r
age_specific_mortality_counts <- subset(age_specific_mortality_counts, Date >= "2020-10-02" & Date <= "2021-01-07")
age_specific_infection_counts <- subset(age_specific_infection_counts, Date >= "2020-10-02" & Date <= "2021-01-07")
```

![](README_files/figure-gfm/mortality_time_series_subset-1.png)<!-- -->

Let’s import the rest of the datasets required for model fitting. First,
import and plot the age distribution for Greece in 2020:

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

## Modeling framework

The aforementioned data streams and expert knowledge are integrated into
a coherent modeling framework via a Bayesian evidence synthesis
approach. Τhe modeling process is separated into a latent epidemic
process and an observation process in an effort to reduce sensitivity to
observation noise and to allow for more flexibility in modeling
different forms of data.

### Diffusion-driven multi-type transmission process

The transmission of COVID-19 is modeled through an age-stratified
deterministic Susceptible-Exposed-Infectious-Removed (SEIR)
compartmental model with Erlang-distributed latent and infectious
periods. In particular, we introduce Erlang-distributed stage durations
in the Exposed and Infected compartments and relax the mathematically
convenient but unrealistic assumption of exponential stage durations by
assuming that each of the Exposed and Infected compartments are defined
by two stages, with the same rate of loss of latency ($\tau$) and
infectiousness ($\gamma$) in both stages. Removed individuals are
assumed to be immune to reinfection for at least the duration of the
study period.

The population is stratified into $\alpha \in \{1,\ldots,A\}$ age groups
and the total size of the age group is denoted by
$\mathbb{N}_{\alpha} = S_t^{\alpha} + E_{1,t}^{\alpha} + E_{2,t}^{\alpha} + I_{1,t}^{\alpha} + I_{2,t}^{\alpha} + R_t^{\alpha}$,
where $S_t^{\alpha}$ represents the number of susceptible,
$E_t^{\alpha} = \sum_{j=1}^{2}E_{j,t}^{\alpha}$ represents the number of
exposed but not yet infectious,
$I_t^{\alpha} = \sum_{j=1}^{2}I_{j,t}^{\alpha}$ is the number of
infected and $R_t^{\alpha}$ is the number of removed individuals at time
$t$ at age group $\alpha$. The number of individuals in each compartment
is scaled by the total population \$ = *{= 1}^{A}*{} \$, so that the sum
of all compartments equals to one . The latent epidemic process is
expressed by the following non-linear system of ordinary differential
equations (ODEs) $$
\begin{cases}
\frac{dS^{\alpha}_{t}}{dt}   & = -\lambda_{\alpha}(t) S^{\alpha}_{t},% - \rho_{\alpha}\nu_{t-u},
\\
\frac{dE^{\alpha}_{1,t}}{dt} & = \lambda_{\alpha}(t) S^{\alpha}_{t} - \tau E^{\alpha}_{1,t},
\\
\frac{dE^{\alpha}_{2,t}}{dt} & = \tau \left( E^{\alpha}_{1,t} - E^{\alpha}_{2,t}\right),
\\
\frac{dI^{\alpha}_{1,t}}{dt} & = \tau E^{\alpha}_{2,t} - \gamma I^{\alpha}_{1,t},
\\
\frac{dI^{\alpha}_{2,t}}{dt} & = \gamma \left( I^{\alpha}_{1,t} - I^{\alpha}_{2,t}\right),
\\
\frac{dR^{\alpha}_{t}}{dt}   & = \gamma I^{\alpha}_{2,t} + \rho_{\alpha}\nu_{t-u},
\end{cases}
$$ where the mean latent and infectious periods are
$d_E = \frac{2}{\tau}$, $d_I = \frac{2}{\gamma}$, respectively. The
number of new infections in age group $\alpha$ at day $t$ is

$$
\Delta^{\text{infec}}_{t, \alpha} = \int_{t-1}^{t} \tau E^{\alpha}_{2,s} ds.
$$

The time-dependent force of infection $\lambda_{\alpha}(t)$ for age
group $\alpha \in \{1,\ldots,A\}$ is expressed as $$
\lambda_{\alpha}(t) = \sum_{\alpha'=1}^{A}\left[ m_{\alpha,\alpha'}(t) \frac{\left(I^{\alpha'}_{1,t} + I^{\alpha'}_{2,t}\right)}{\mathbb{N}_{\alpha'}}\right],
$$

which is a function of the proportion of infectious individuals in each
age group $\alpha' \in \{1,\ldots,A\}$, via the compartments
$I^{\alpha'}_{1,t}$, $I^{\alpha'}_{2,t}$ divided by the total size of
the age group $\mathbb{N}_{\alpha'}$, and the time-varying
person-to-person transmission rate from group $\alpha$ to group
$\alpha'$, $m_{\alpha,\alpha'}(t)$. We parameterize the transmission
rate between different age groups
$(\alpha,\alpha') \in \{1,\ldots,A\}^2$ by

$m_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}_{t} \cdot C_{\alpha,\alpha'},$

breaking down the transmission rate matrix into its biological and
social components : the social component is represented by the average
number of contacts between individuals of age group $\alpha$ and age
group $\alpha'$ viThe number of individuals in each compartment is
scaled by the total populationa the contact matrix element
$C_{\alpha,\alpha'}$; $\beta^{\alpha\alpha'}_{t}$ is the time-varying
transmissibility of the virus, the probability that a contact between an
infectious person in age group $\alpha$ and a susceptible person in age
group $\alpha'$ leads to transmission at time $t$.

The formulation below may be viewed as a stochastic extension to the
deterministic multi-type SEIR model, using diffusion processes for the
coefficients $\beta^{\alpha\alpha'}_{t}$ in , driven by independent
Brownian motions

$$
\begin{cases}
\beta^{\alpha\alpha'}_{t} & = \exp(x^{\alpha\alpha'}_{t}), 
\\
x^{\alpha\alpha'}_{t} \mid x^{\alpha\alpha'}_{t - 1}, \sigma^{\alpha\alpha'}_x & \sim \operatorname{N}(x^{\alpha\alpha'}_{t - 1}, (\sigma^{\alpha\alpha'})^2_x), 
\\
dx^{\alpha\alpha'}_{t} & = \sigma^{\alpha\alpha'}_{x}dW^{\alpha\alpha'}_{t},
\\
dW^{\alpha\alpha'}_{t} & \sim \operatorname{N}(0,d_{t}),
\end{cases}
$$

with volatilities $\sigma^{\alpha\alpha'}_x$, corresponding to the case
of little information on the shape of $\beta^{\alpha\alpha'}_{t}$. The
volatility $\sigma^{\alpha\alpha'}_x$ plays the role of the regularizing
factor: higher values of $\sigma^{\alpha\alpha'}_x$ lead to greater
changes in $\beta^{\alpha\alpha'}_{t}$. The exponential transformation
avoids negative values which have no biological meaning. A major
advantage of considering a diffusion process for modeling
$\beta^{\alpha\alpha'}_{t}$ is its ability to capture and quantify the
randomness of the underlying transmission dynamics, which is
particularly useful when the dynamics are not completely understood. The
diffusion process accounts for fluctuations in transmission that are
influenced by non-modeled phenomena, such as new variants, mask-wearing
propensity, etc. The diffusion process also allows for capturing the
effect of unknown extrinsic factors on the age-stratified force of
infection, for monitoring of the temporal evolution of the age-specific
transmission rate without the implicit inclusion of external variables
and for tackling non-stationarity in the data.

We propose a diffusion-driven multi-type latent transmission model which
assigns independent Brownian motions to
$\log(\beta^{11}_{t}), \log(\beta^{22}_{t}), \ldots, \log(\beta^{AA}_{t})$
with respective age-stratified volatility parameters
$\sigma_{x,\alpha}, \alpha \in \{1,\ldots,A\}$, for reasons of parsimony
and interpretability. The contact matrix is scaled by the age-stratified
transmissibility in order to obtain the transmission rate matrix process
$$
m_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}_{t}
\cdot
C_{\alpha,\alpha'}
\equiv 
\beta^{\alpha\alpha}_{t}
\cdot
C_{\alpha,\alpha'},
$$

under the assumption
$\beta^{\alpha\alpha'}_t \equiv \beta^{\alpha\alpha}_t, \alpha \neq \alpha'$.

### Observation process

Denote the number of observed deaths on day $t = 1, \ldots, T$ in age
group $\alpha \in \{1,\ldots,A\}$ by $y_{t,\alpha}$. A given infection
may lead to observation events (i.e deaths) in the future. A link
between $y_{t,\alpha}$ and the expected number of new age-stratified
infections is established via the function $$
\begin{equation*}
d_{t,\alpha} = \mathbb{E}[y_{t,\alpha}] = \widehat{\text{IFR}}_{\alpha} \times \sum_{s = 1}^{t-1}h_{t-s} \Delta^{\text{infec}}_{s, \alpha}
\end{equation*}
$$ on the new expected age-stratified mortality counts, $d_{t,\alpha}$,
the estimated age-stratified infection fatality rate,
$\widehat{\text{IFR}}_{\alpha}$, and the infection-to-death distribution
$h$, where $h_s$ gives the probability the death occurs on the $s^{th}$
day after infection, is assumed to be gamma distributed with mean 24.2
days and coefficient of variation 0.39 , that is $$
\begin{equation}\label{eq:itd}
h \sim \operatorname{Gamma}(6.29, 0.26).
\end{equation}
$$ We allow for over-dispersion in the observation processes to account
for noise in the underlying data streams, for example due to day-of-week
effects on data collection, and link $d_{t,\alpha}$ to $y_{t,\alpha}$
through an over-dispersed count model $$
\begin{equation}\label{eq:negbin}
  y_{t,\alpha}\mid \theta \sim \operatorname{NegBin}\left(d_{t,\alpha}, \xi_{t,\alpha}\right),
\end{equation}
$$ where $\xi_{t,\alpha} = \frac{d_{t,\alpha}}{\phi}$, such that
$\mathbb{V}[y_{t,\alpha}] = d_{t,\alpha}(1+\phi)$. The log-likelihood of
the observed deaths is given by $$
\begin{equation*}
\ell^{Deaths}(y\mid \theta) = \sum_{t=1}^{T}\sum_{\alpha=1}^{A}\text{logNegBin}\left(y_{t,\alpha}\mid d_{t,\alpha}, \xi_{t,\alpha}\right),
\end{equation*}
$$ where $y \in \mathbb{R}^{T \times A}_{0,+}$ are the surveillance data
on deaths for all time-points.

### Prior specification

## Model fitting

Before performing MCMC, the user can opt to execute the routine for
maximizing the joint posterior from the model. The estimates can be used
as initialization points for the HMC algorithm by setting the option
`r, eval=F init = igbm_fit_init` in `r, eval=F stan_igbm`.

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
