
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

## Contribution

This R package is provided for use under the
[GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) License by the
author. Please use the [issue
tracker](https://github.com/bernadette-eu/Bernadette/issues) for bug
reports and feature requests. All contributions are welcome, in
particular those that improve the approach or the robustness of the code
base. We also welcome additions and extensions to the underlying model
either in the form of options or improvements.

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

![](README_files/figure-gfm/unnamed-chunk-7-1.png)<!-- -->

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

![](README_files/figure-gfm/unnamed-chunk-8-1.png)<!-- -->

Next, import the projected contact matrix for Greece:

``` r
conmat <- contact_matrix(country = "GRC")
plot_contact_matrix(conmat)
```

![](README_files/figure-gfm/unnamed-chunk-9-1.png)<!-- -->

Aggregate the contact matrix to the age groups {0-39, 40-64, 65+}:

``` r
aggr_cm <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)
plot_contact_matrix(aggr_cm)
```

![](README_files/figure-gfm/unnamed-chunk-10-1.png)<!-- -->

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
by two stages, with the same rate of loss of latency
(![\tau](https://latex.codecogs.com/png.latex?%5Ctau "\tau")) and
infectiousness
(![\gamma](https://latex.codecogs.com/png.latex?%5Cgamma "\gamma")) in
both stages. Removed individuals are assumed to be immune to reinfection
for at least the duration of the study period.

The population is stratified into
![\alpha \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Calpha%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\alpha \in \{1,\ldots,A\}")
age groups and the total size of the age group is denoted by
![N\_{\alpha} = S_t^{\alpha} + E\_{1,t}^{\alpha} + E\_{2,t}^{\alpha} + I\_{1,t}^{\alpha} + I\_{2,t}^{\alpha} + R_t^{\alpha}](https://latex.codecogs.com/png.latex?N_%7B%5Calpha%7D%20%3D%20S_t%5E%7B%5Calpha%7D%20%2B%20E_%7B1%2Ct%7D%5E%7B%5Calpha%7D%20%2B%20E_%7B2%2Ct%7D%5E%7B%5Calpha%7D%20%2B%20I_%7B1%2Ct%7D%5E%7B%5Calpha%7D%20%2B%20I_%7B2%2Ct%7D%5E%7B%5Calpha%7D%20%2B%20R_t%5E%7B%5Calpha%7D "N_{\alpha} = S_t^{\alpha} + E_{1,t}^{\alpha} + E_{2,t}^{\alpha} + I_{1,t}^{\alpha} + I_{2,t}^{\alpha} + R_t^{\alpha}"),
where
![S_t^{\alpha}](https://latex.codecogs.com/png.latex?S_t%5E%7B%5Calpha%7D "S_t^{\alpha}")
represents the number of susceptible,
![E_t^{\alpha} = \sum\_{j=1}^{2}E\_{j,t}^{\alpha}](https://latex.codecogs.com/png.latex?E_t%5E%7B%5Calpha%7D%20%3D%20%5Csum_%7Bj%3D1%7D%5E%7B2%7DE_%7Bj%2Ct%7D%5E%7B%5Calpha%7D "E_t^{\alpha} = \sum_{j=1}^{2}E_{j,t}^{\alpha}")
represents the number of exposed but not yet infectious,
![I_t^{\alpha} = \sum\_{j=1}^{2}I\_{j,t}^{\alpha}](https://latex.codecogs.com/png.latex?I_t%5E%7B%5Calpha%7D%20%3D%20%5Csum_%7Bj%3D1%7D%5E%7B2%7DI_%7Bj%2Ct%7D%5E%7B%5Calpha%7D "I_t^{\alpha} = \sum_{j=1}^{2}I_{j,t}^{\alpha}")
is the number of infected and
![R_t^{\alpha}](https://latex.codecogs.com/png.latex?R_t%5E%7B%5Calpha%7D "R_t^{\alpha}")
is the number of removed individuals at time
![t](https://latex.codecogs.com/png.latex?t "t") at age group
![\alpha](https://latex.codecogs.com/png.latex?%5Calpha "\alpha"). The
number of individuals in each compartment is scaled by the total
population
![N = \sum\_{\alpha = 1}^{A}N\_{\alpha}](https://latex.codecogs.com/png.latex?N%20%3D%20%5Csum_%7B%5Calpha%20%3D%201%7D%5E%7BA%7DN_%7B%5Calpha%7D "N = \sum_{\alpha = 1}^{A}N_{\alpha}"),
so that the sum of all compartments equals to one. The latent epidemic
process is expressed by the following non-linear system of ordinary
differential equations (ODEs)

![\begin{cases}
\frac{dS^{\alpha}\_{t}}{dt}   & = -\lambda\_{\alpha}(t) S^{\alpha}\_{t},
\\\\
\frac{dE^{\alpha}\_{1,t}}{dt} & = \lambda\_{\alpha}(t) S^{\alpha}\_{t} - \tau E^{\alpha}\_{1,t},
\\\\
\frac{dE^{\alpha}\_{2,t}}{dt} & = \tau \left( E^{\alpha}\_{1,t} - E^{\alpha}\_{2,t}\right),
\\\\
\frac{dI^{\alpha}\_{1,t}}{dt} & = \tau E^{\alpha}\_{2,t} - \gamma I^{\alpha}\_{1,t},
\\\\
\frac{dI^{\alpha}\_{2,t}}{dt} & = \gamma \left( I^{\alpha}\_{1,t} - I^{\alpha}\_{2,t}\right),
\\\\
\frac{dR^{\alpha}\_{t}}{dt}   & = \gamma I^{\alpha}\_{2,t},
\end{cases}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bcases%7D%0A%5Cfrac%7BdS%5E%7B%5Calpha%7D_%7Bt%7D%7D%7Bdt%7D%20%20%20%26%20%3D%20-%5Clambda_%7B%5Calpha%7D%28t%29%20S%5E%7B%5Calpha%7D_%7Bt%7D%2C%0A%5C%5C%0A%5Cfrac%7BdE%5E%7B%5Calpha%7D_%7B1%2Ct%7D%7D%7Bdt%7D%20%26%20%3D%20%5Clambda_%7B%5Calpha%7D%28t%29%20S%5E%7B%5Calpha%7D_%7Bt%7D%20-%20%5Ctau%20E%5E%7B%5Calpha%7D_%7B1%2Ct%7D%2C%0A%5C%5C%0A%5Cfrac%7BdE%5E%7B%5Calpha%7D_%7B2%2Ct%7D%7D%7Bdt%7D%20%26%20%3D%20%5Ctau%20%5Cleft%28%20E%5E%7B%5Calpha%7D_%7B1%2Ct%7D%20-%20E%5E%7B%5Calpha%7D_%7B2%2Ct%7D%5Cright%29%2C%0A%5C%5C%0A%5Cfrac%7BdI%5E%7B%5Calpha%7D_%7B1%2Ct%7D%7D%7Bdt%7D%20%26%20%3D%20%5Ctau%20E%5E%7B%5Calpha%7D_%7B2%2Ct%7D%20-%20%5Cgamma%20I%5E%7B%5Calpha%7D_%7B1%2Ct%7D%2C%0A%5C%5C%0A%5Cfrac%7BdI%5E%7B%5Calpha%7D_%7B2%2Ct%7D%7D%7Bdt%7D%20%26%20%3D%20%5Cgamma%20%5Cleft%28%20I%5E%7B%5Calpha%7D_%7B1%2Ct%7D%20-%20I%5E%7B%5Calpha%7D_%7B2%2Ct%7D%5Cright%29%2C%0A%5C%5C%0A%5Cfrac%7BdR%5E%7B%5Calpha%7D_%7Bt%7D%7D%7Bdt%7D%20%20%20%26%20%3D%20%5Cgamma%20I%5E%7B%5Calpha%7D_%7B2%2Ct%7D%2C%0A%5Cend%7Bcases%7D "\begin{cases}
\frac{dS^{\alpha}_{t}}{dt}   & = -\lambda_{\alpha}(t) S^{\alpha}_{t},
\\
\frac{dE^{\alpha}_{1,t}}{dt} & = \lambda_{\alpha}(t) S^{\alpha}_{t} - \tau E^{\alpha}_{1,t},
\\
\frac{dE^{\alpha}_{2,t}}{dt} & = \tau \left( E^{\alpha}_{1,t} - E^{\alpha}_{2,t}\right),
\\
\frac{dI^{\alpha}_{1,t}}{dt} & = \tau E^{\alpha}_{2,t} - \gamma I^{\alpha}_{1,t},
\\
\frac{dI^{\alpha}_{2,t}}{dt} & = \gamma \left( I^{\alpha}_{1,t} - I^{\alpha}_{2,t}\right),
\\
\frac{dR^{\alpha}_{t}}{dt}   & = \gamma I^{\alpha}_{2,t},
\end{cases}")

where the mean latent and infectious periods are
![d_E = \frac{2}{\tau}](https://latex.codecogs.com/png.latex?d_E%20%3D%20%5Cfrac%7B2%7D%7B%5Ctau%7D "d_E = \frac{2}{\tau}"),
![d_I = \frac{2}{\gamma}](https://latex.codecogs.com/png.latex?d_I%20%3D%20%5Cfrac%7B2%7D%7B%5Cgamma%7D "d_I = \frac{2}{\gamma}"),
respectively. The number of new infections in age group
![\alpha](https://latex.codecogs.com/png.latex?%5Calpha "\alpha") at day
![t](https://latex.codecogs.com/png.latex?t "t") is

![\Delta^{\text{infec}}\_{t, \alpha} = \int\_{t-1}^{t} \tau E^{\alpha}\_{2,s} ds.](https://latex.codecogs.com/png.latex?%5CDelta%5E%7B%5Ctext%7Binfec%7D%7D_%7Bt%2C%20%5Calpha%7D%20%3D%20%5Cint_%7Bt-1%7D%5E%7Bt%7D%20%5Ctau%20E%5E%7B%5Calpha%7D_%7B2%2Cs%7D%20ds. "\Delta^{\text{infec}}_{t, \alpha} = \int_{t-1}^{t} \tau E^{\alpha}_{2,s} ds.")

The time-dependent force of infection
![\lambda\_{\alpha}(t)](https://latex.codecogs.com/png.latex?%5Clambda_%7B%5Calpha%7D%28t%29 "\lambda_{\alpha}(t)")
for age group
![\alpha \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Calpha%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\alpha \in \{1,\ldots,A\}")
is expressed as

![\lambda\_{\alpha}(t) = \sum\_{\alpha'=1}^{A}\left\[ m\_{\alpha,\alpha'}(t) \frac{\left(I^{\alpha'}\_{1,t} + I^{\alpha'}\_{2,t}\right)}{\mathbb{N}\_{\alpha'}}\right\],](https://latex.codecogs.com/png.latex?%5Clambda_%7B%5Calpha%7D%28t%29%20%3D%20%5Csum_%7B%5Calpha%27%3D1%7D%5E%7BA%7D%5Cleft%5B%20m_%7B%5Calpha%2C%5Calpha%27%7D%28t%29%20%5Cfrac%7B%5Cleft%28I%5E%7B%5Calpha%27%7D_%7B1%2Ct%7D%20%2B%20I%5E%7B%5Calpha%27%7D_%7B2%2Ct%7D%5Cright%29%7D%7B%5Cmathbb%7BN%7D_%7B%5Calpha%27%7D%7D%5Cright%5D%2C "\lambda_{\alpha}(t) = \sum_{\alpha'=1}^{A}\left[ m_{\alpha,\alpha'}(t) \frac{\left(I^{\alpha'}_{1,t} + I^{\alpha'}_{2,t}\right)}{\mathbb{N}_{\alpha'}}\right],")

which is a function of the proportion of infectious individuals in each
age group
![\alpha' \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Calpha%27%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\alpha' \in \{1,\ldots,A\}"),
via the compartments
![I^{\alpha'}\_{1,t}](https://latex.codecogs.com/png.latex?I%5E%7B%5Calpha%27%7D_%7B1%2Ct%7D "I^{\alpha'}_{1,t}"),
![I^{\alpha'}\_{2,t}](https://latex.codecogs.com/png.latex?I%5E%7B%5Calpha%27%7D_%7B2%2Ct%7D "I^{\alpha'}_{2,t}")
divided by the total size of the age group
![\mathbb{N}\_{\alpha'}](https://latex.codecogs.com/png.latex?%5Cmathbb%7BN%7D_%7B%5Calpha%27%7D "\mathbb{N}_{\alpha'}"),
and the time-varying person-to-person transmission rate from group
![\alpha](https://latex.codecogs.com/png.latex?%5Calpha "\alpha") to
group
![\alpha'](https://latex.codecogs.com/png.latex?%5Calpha%27 "\alpha'"),
![m\_{\alpha,\alpha'}(t)](https://latex.codecogs.com/png.latex?m_%7B%5Calpha%2C%5Calpha%27%7D%28t%29 "m_{\alpha,\alpha'}(t)").
We parameterize the transmission rate between different age groups
![(\alpha,\alpha') \in \\{1,\ldots,A\\}^2](https://latex.codecogs.com/png.latex?%28%5Calpha%2C%5Calpha%27%29%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D%5E2 "(\alpha,\alpha') \in \{1,\ldots,A\}^2")
by

![m\_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}\_{t} \cdot C\_{\alpha,\alpha'},](https://latex.codecogs.com/png.latex?m_%7B%5Calpha%2C%5Calpha%27%7D%28t%29%20%3D%20%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%20%5Ccdot%20C_%7B%5Calpha%2C%5Calpha%27%7D%2C "m_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}_{t} \cdot C_{\alpha,\alpha'},")

breaking down the transmission rate matrix into its biological and
social components: the social component is represented by the average
number of contacts between individuals of age group
![\alpha](https://latex.codecogs.com/png.latex?%5Calpha "\alpha") and
age group
![\alpha'](https://latex.codecogs.com/png.latex?%5Calpha%27 "\alpha'")
via the contact matrix element
![C\_{\alpha,\alpha'}](https://latex.codecogs.com/png.latex?C_%7B%5Calpha%2C%5Calpha%27%7D "C_{\alpha,\alpha'}");
![\beta^{\alpha\alpha'}\_{t}](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D "\beta^{\alpha\alpha'}_{t}")
is the time-varying transmissibility of the virus, the probability that
a contact between an infectious person in age group
![\alpha](https://latex.codecogs.com/png.latex?%5Calpha "\alpha") and a
susceptible person in age group
![\alpha'](https://latex.codecogs.com/png.latex?%5Calpha%27 "\alpha'")
leads to transmission at time
![t](https://latex.codecogs.com/png.latex?t "t").

The formulation below may be viewed as a stochastic extension to the
deterministic multi-type SEIR model, using diffusion processes for the
coefficients
![\beta^{\alpha\alpha'}\_{t}](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D "\beta^{\alpha\alpha'}_{t}"),
driven by independent Brownian motions

![\begin{cases}
\beta^{\alpha\alpha'}\_{t} & = \exp(x^{\alpha\alpha'}\_{t}), 
\\\\
x^{\alpha\alpha'}\_{t} \mid x^{\alpha\alpha'}\_{t - 1}, \sigma^{\alpha\alpha'}\_x & \sim \operatorname{N}(x^{\alpha\alpha'}\_{t - 1}, (\sigma^{\alpha\alpha'})^2_x), 
\\\\
dx^{\alpha\alpha'}\_{t} & = \sigma^{\alpha\alpha'}\_{x}dW^{\alpha\alpha'}\_{t},
\\\\
dW^{\alpha\alpha'}\_{t} & \sim \operatorname{N}(0,d\_{t}),
\end{cases}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bcases%7D%0A%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%20%26%20%3D%20%5Cexp%28x%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%29%2C%20%0A%5C%5C%0Ax%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%20%5Cmid%20x%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%20-%201%7D%2C%20%5Csigma%5E%7B%5Calpha%5Calpha%27%7D_x%20%26%20%5Csim%20%5Coperatorname%7BN%7D%28x%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%20-%201%7D%2C%20%28%5Csigma%5E%7B%5Calpha%5Calpha%27%7D%29%5E2_x%29%2C%20%0A%5C%5C%0Adx%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%20%26%20%3D%20%5Csigma%5E%7B%5Calpha%5Calpha%27%7D_%7Bx%7DdW%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%2C%0A%5C%5C%0AdW%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%20%26%20%5Csim%20%5Coperatorname%7BN%7D%280%2Cd_%7Bt%7D%29%2C%0A%5Cend%7Bcases%7D "\begin{cases}
\beta^{\alpha\alpha'}_{t} & = \exp(x^{\alpha\alpha'}_{t}), 
\\
x^{\alpha\alpha'}_{t} \mid x^{\alpha\alpha'}_{t - 1}, \sigma^{\alpha\alpha'}_x & \sim \operatorname{N}(x^{\alpha\alpha'}_{t - 1}, (\sigma^{\alpha\alpha'})^2_x), 
\\
dx^{\alpha\alpha'}_{t} & = \sigma^{\alpha\alpha'}_{x}dW^{\alpha\alpha'}_{t},
\\
dW^{\alpha\alpha'}_{t} & \sim \operatorname{N}(0,d_{t}),
\end{cases}")

with volatilities
![\sigma^{\alpha\alpha'}\_x](https://latex.codecogs.com/png.latex?%5Csigma%5E%7B%5Calpha%5Calpha%27%7D_x "\sigma^{\alpha\alpha'}_x"),
corresponding to the case of little information on the shape of
![\beta^{\alpha\alpha'}\_{t}](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D "\beta^{\alpha\alpha'}_{t}").
The volatility
![\sigma^{\alpha\alpha'}\_x](https://latex.codecogs.com/png.latex?%5Csigma%5E%7B%5Calpha%5Calpha%27%7D_x "\sigma^{\alpha\alpha'}_x")
plays the role of the regularizing factor: higher values of
![\sigma^{\alpha\alpha'}\_x](https://latex.codecogs.com/png.latex?%5Csigma%5E%7B%5Calpha%5Calpha%27%7D_x "\sigma^{\alpha\alpha'}_x")
lead to greater changes in
![\beta^{\alpha\alpha'}\_{t}](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D "\beta^{\alpha\alpha'}_{t}").
The exponential transformation avoids negative values which have no
biological meaning.

A major advantage of considering a diffusion process for modeling
![\beta^{\alpha\alpha'}\_{t}](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D "\beta^{\alpha\alpha'}_{t}")
is its ability to capture and quantify the randomness of the underlying
transmission dynamics, which is particularly useful when the dynamics
are not completely understood. The diffusion process accounts for
fluctuations in transmission that are influenced by non-modeled
phenomena, such as new variants, mask-wearing propensity, etc. The
diffusion process also allows for capturing the effect of unknown
extrinsic factors on the age-stratified force of infection, for
monitoring of the temporal evolution of the age-specific transmission
rate without the implicit inclusion of external variables and for
tackling non-stationarity in the data.

We propose a diffusion-driven multi-type latent transmission model which
assigns independent Brownian motions to
![\log(\beta^{11}\_{t}), \log(\beta^{22}\_{t}), \ldots, \log(\beta^{AA}\_{t})](https://latex.codecogs.com/png.latex?%5Clog%28%5Cbeta%5E%7B11%7D_%7Bt%7D%29%2C%20%5Clog%28%5Cbeta%5E%7B22%7D_%7Bt%7D%29%2C%20%5Cldots%2C%20%5Clog%28%5Cbeta%5E%7BAA%7D_%7Bt%7D%29 "\log(\beta^{11}_{t}), \log(\beta^{22}_{t}), \ldots, \log(\beta^{AA}_{t})")
with respective age-stratified volatility parameters
![\sigma\_{x,\alpha}, \alpha \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Csigma_%7Bx%2C%5Calpha%7D%2C%20%5Calpha%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\sigma_{x,\alpha}, \alpha \in \{1,\ldots,A\}"),
for reasons of parsimony and interpretability. The contact matrix is
scaled by the age-stratified transmissibility in order to obtain the
transmission rate matrix process

![m\_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}\_{t}
\cdot
C\_{\alpha,\alpha'}
\equiv 
\beta^{\alpha\alpha}\_{t}
\cdot
C\_{\alpha,\alpha'}](https://latex.codecogs.com/png.latex?m_%7B%5Calpha%2C%5Calpha%27%7D%28t%29%20%3D%20%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_%7Bt%7D%0A%5Ccdot%0AC_%7B%5Calpha%2C%5Calpha%27%7D%0A%5Cequiv%20%0A%5Cbeta%5E%7B%5Calpha%5Calpha%7D_%7Bt%7D%0A%5Ccdot%0AC_%7B%5Calpha%2C%5Calpha%27%7D "m_{\alpha,\alpha'}(t) = \beta^{\alpha\alpha'}_{t}
\cdot
C_{\alpha,\alpha'}
\equiv 
\beta^{\alpha\alpha}_{t}
\cdot
C_{\alpha,\alpha'}")

under the assumption
![\beta^{\alpha\alpha'}\_t \equiv \beta^{\alpha\alpha}\_t, \alpha \neq \alpha'](https://latex.codecogs.com/png.latex?%5Cbeta%5E%7B%5Calpha%5Calpha%27%7D_t%20%5Cequiv%20%5Cbeta%5E%7B%5Calpha%5Calpha%7D_t%2C%20%5Calpha%20%5Cneq%20%5Calpha%27 "\beta^{\alpha\alpha'}_t \equiv \beta^{\alpha\alpha}_t, \alpha \neq \alpha'").

### Observation process

Denote the number of observed deaths on day
![t = 1, \ldots, T](https://latex.codecogs.com/png.latex?t%20%3D%201%2C%20%5Cldots%2C%20T "t = 1, \ldots, T")
in age group
![\alpha \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Calpha%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\alpha \in \{1,\ldots,A\}")
by
![y\_{t,\alpha}](https://latex.codecogs.com/png.latex?y_%7Bt%2C%5Calpha%7D "y_{t,\alpha}").
A given infection may lead to observation events (i.e deaths) in the
future. A link between
![y\_{t,\alpha}](https://latex.codecogs.com/png.latex?y_%7Bt%2C%5Calpha%7D "y_{t,\alpha}")
and the expected number of new age-stratified infections is established
via the function

![\begin{equation}
d\_{t,\alpha} = \mathbb{E}\[y\_{t,\alpha}\] = \widehat{\text{IFR}}\_{\alpha} \times \sum\_{s = 1}^{t-1}h\_{t-s} \Delta^{\text{infec}}\_{s, \alpha}
\end{equation}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bequation%7D%0Ad_%7Bt%2C%5Calpha%7D%20%3D%20%5Cmathbb%7BE%7D%5By_%7Bt%2C%5Calpha%7D%5D%20%3D%20%5Cwidehat%7B%5Ctext%7BIFR%7D%7D_%7B%5Calpha%7D%20%5Ctimes%20%5Csum_%7Bs%20%3D%201%7D%5E%7Bt-1%7Dh_%7Bt-s%7D%20%5CDelta%5E%7B%5Ctext%7Binfec%7D%7D_%7Bs%2C%20%5Calpha%7D%0A%5Cend%7Bequation%7D "\begin{equation}
d_{t,\alpha} = \mathbb{E}[y_{t,\alpha}] = \widehat{\text{IFR}}_{\alpha} \times \sum_{s = 1}^{t-1}h_{t-s} \Delta^{\text{infec}}_{s, \alpha}
\end{equation}")

on the new expected age-stratified mortality counts,
![d\_{t,\alpha}](https://latex.codecogs.com/png.latex?d_%7Bt%2C%5Calpha%7D "d_{t,\alpha}"),
the estimated age-stratified infection fatality rate,
![\widehat{\text{IFR}}\_{\alpha}](https://latex.codecogs.com/png.latex?%5Cwidehat%7B%5Ctext%7BIFR%7D%7D_%7B%5Calpha%7D "\widehat{\text{IFR}}_{\alpha}"),
and the infection-to-death distribution
![h](https://latex.codecogs.com/png.latex?h "h"), where
![h_s](https://latex.codecogs.com/png.latex?h_s "h_s") gives the
probability the death occurs on the
![s^{th}](https://latex.codecogs.com/png.latex?s%5E%7Bth%7D "s^{th}")
day after infection, is assumed to be gamma distributed with mean 24.2
days and coefficient of variation 0.39, that is

![\begin{equation}
h \sim \operatorname{Gamma}(6.29, 0.26).
\end{equation}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bequation%7D%0Ah%20%5Csim%20%5Coperatorname%7BGamma%7D%286.29%2C%200.26%29.%0A%5Cend%7Bequation%7D "\begin{equation}
h \sim \operatorname{Gamma}(6.29, 0.26).
\end{equation}")

We allow for over-dispersion in the observation processes to account for
noise in the underlying data streams, for example due to day-of-week
effects on data collection, and link
![d\_{t,\alpha}](https://latex.codecogs.com/png.latex?d_%7Bt%2C%5Calpha%7D "d_{t,\alpha}")
to
![y\_{t,\alpha}](https://latex.codecogs.com/png.latex?y_%7Bt%2C%5Calpha%7D "y_{t,\alpha}")
through an over-dispersed count model

![\begin{equation}
  y\_{t,\alpha}\mid \theta \sim \operatorname{NegBin}\left(d\_{t,\alpha}, \xi\_{t,\alpha}\right),
\end{equation}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bequation%7D%0A%20%20y_%7Bt%2C%5Calpha%7D%5Cmid%20%5Ctheta%20%5Csim%20%5Coperatorname%7BNegBin%7D%5Cleft%28d_%7Bt%2C%5Calpha%7D%2C%20%5Cxi_%7Bt%2C%5Calpha%7D%5Cright%29%2C%0A%5Cend%7Bequation%7D "\begin{equation}
  y_{t,\alpha}\mid \theta \sim \operatorname{NegBin}\left(d_{t,\alpha}, \xi_{t,\alpha}\right),
\end{equation}")

where
![\xi\_{t,\alpha} = \frac{d\_{t,\alpha}}{\phi}](https://latex.codecogs.com/png.latex?%5Cxi_%7Bt%2C%5Calpha%7D%20%3D%20%5Cfrac%7Bd_%7Bt%2C%5Calpha%7D%7D%7B%5Cphi%7D "\xi_{t,\alpha} = \frac{d_{t,\alpha}}{\phi}"),
such that
![\mathbb{V}\[y\_{t,\alpha}\] = d\_{t,\alpha}(1+\phi)](https://latex.codecogs.com/png.latex?%5Cmathbb%7BV%7D%5By_%7Bt%2C%5Calpha%7D%5D%20%3D%20d_%7Bt%2C%5Calpha%7D%281%2B%5Cphi%29 "\mathbb{V}[y_{t,\alpha}] = d_{t,\alpha}(1+\phi)").
The log-likelihood of the observed deaths is given by

![\begin{equation}
\ell^{Deaths}(y\mid \theta) = \sum\_{t=1}^{T}\sum\_{\alpha=1}^{A}\text{logNegBin}\left(y\_{t,\alpha}\mid d\_{t,\alpha}, \xi\_{t,\alpha}\right),
\end{equation}](https://latex.codecogs.com/png.latex?%5Cbegin%7Bequation%7D%0A%5Cell%5E%7BDeaths%7D%28y%5Cmid%20%5Ctheta%29%20%3D%20%5Csum_%7Bt%3D1%7D%5E%7BT%7D%5Csum_%7B%5Calpha%3D1%7D%5E%7BA%7D%5Ctext%7BlogNegBin%7D%5Cleft%28y_%7Bt%2C%5Calpha%7D%5Cmid%20d_%7Bt%2C%5Calpha%7D%2C%20%5Cxi_%7Bt%2C%5Calpha%7D%5Cright%29%2C%0A%5Cend%7Bequation%7D "\begin{equation}
\ell^{Deaths}(y\mid \theta) = \sum_{t=1}^{T}\sum_{\alpha=1}^{A}\text{logNegBin}\left(y_{t,\alpha}\mid d_{t,\alpha}, \xi_{t,\alpha}\right),
\end{equation}")

where
![y \in \mathbb{R}^{T \times A}\_{0,+}](https://latex.codecogs.com/png.latex?y%20%5Cin%20%5Cmathbb%7BR%7D%5E%7BT%20%5Ctimes%20A%7D_%7B0%2C%2B%7D "y \in \mathbb{R}^{T \times A}_{0,+}")
are the surveillance data on deaths for all time-points.

### Prior specification

The unknown quantities that need to be inferred are
![\theta= (x^{\alpha\alpha}\_{0}, x^{\alpha\alpha}\_{1:T}, C\_{\alpha,\alpha'}, \sigma\_{x,\alpha}, \rho, \phi)](https://latex.codecogs.com/png.latex?%5Ctheta%3D%20%28x%5E%7B%5Calpha%5Calpha%7D_%7B0%7D%2C%20x%5E%7B%5Calpha%5Calpha%7D_%7B1%3AT%7D%2C%20C_%7B%5Calpha%2C%5Calpha%27%7D%2C%20%5Csigma_%7Bx%2C%5Calpha%7D%2C%20%5Crho%2C%20%5Cphi%29 "\theta= (x^{\alpha\alpha}_{0}, x^{\alpha\alpha}_{1:T}, C_{\alpha,\alpha'}, \sigma_{x,\alpha}, \rho, \phi)")
for
![\alpha \in \\{1,\ldots,A\\}](https://latex.codecogs.com/png.latex?%5Calpha%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D "\alpha \in \{1,\ldots,A\}")
for
![(\alpha,\alpha') \in \\{1,\ldots,A\\}^2](https://latex.codecogs.com/png.latex?%28%5Calpha%2C%5Calpha%27%29%20%5Cin%20%5C%7B1%2C%5Cldots%2CA%5C%7D%5E2 "(\alpha,\alpha') \in \{1,\ldots,A\}^2")

The proposed prior distributions for the model parameters are:

## Model fitting

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
