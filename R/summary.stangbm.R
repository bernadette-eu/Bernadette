#' Summary of stanigbm posterior output
#'
#' This function summarizes the MCMC output for \code{stanigbm} objects.
#'
#' @param object
#' An \code{R} object of class \code{stanigbm}.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @param ...
#' Additional arguments, to be passed to lower-level functions.
#'
#' @return A named list with elements \code{summary} and \code{c_summary},
#' which contain summaries for for all Markov chains merged and  individual chains,
#' respectively. See \code{\link[rstan]{stanfit-method-summary}}.
#'
#' @examples
#' \donttest{
#' # Age-specific mortality/incidence count time series:
#' data(age_specific_mortality_counts)
#' data(age_specific_infection_counts)
#'
#' # Import the age distribution for Greece in 2020:
#' age_distr <- age_distribution(country = "Greece", year = 2020)
#'
#' # Lookup table:
#' lookup_table <- data.frame(Initial = age_distr$AgeGrp,
#'                           Mapping = c(rep("0-39",  8),
#'                                       rep("40-64", 5),
#'                                       rep("65+"  , 3)))
#'
#' # Aggregate the age distribution table:
#' aggr_age <- aggregate_age_distribution(age_distr, lookup_table)
#'
#' # Import the projected contact matrix for Greece:
#' conmat <- contact_matrix(country = "GRC")
#'
#' # Aggregate the contact matrix:
#' aggr_cm <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)
#'
#' # Aggregate the IFR:
#' ifr_mapping <- c(rep("0-39", 8), rep("40-64", 5), rep("65+", 3))
#'
#' aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_infection_counts)
#'
#' # Infection-to-death distribution:
#' ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
#'                          gamma_mean = 24.19231,
#'                          gamma_cv   = 0.3987261)
#'
#' # Posterior sampling:
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       itd_distr                   = ditd,
#'                       likelihood_variance_type    = "quadratic",
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = gamma(shape = 2, rate = 1),
#'                       algorithm_inference         = "optimizing")
#'
#' summary(object = igbm_fit,
#'         y_data = age_specific_mortality_counts)
#'}
#'
#' @export
#'
#' @method summary stanigbm
#'
summary.stanigbm <- function(object,
                             y_data,
                             ...) {

  check <- check_stanfit(object)

  if (!isTRUE(check)) stop("'object' must be of class 'stanfit'.")

  parameters <- c("pi",
                  "phiD",
                  "volatilities",
                  "cm_sample",
                  "beta0",
                  "beta_trajectory",
                  "E_casesByAge",
                  "E_deathsByAge",
                  "E_cases",
                  "E_deaths",
                  "Susceptibles")

  cov_data       <- list()
  cov_data$A     <- ncol(y_data[,-c(1:5)])
  cov_data$n_obs <- nrow(y_data)

  rest_params <-
    c(parameters[1],
      parameters[2],
      paste0(parameters[3],"[", 1:cov_data$A,"]"),
      parameters[5]
      )

  cm_params <-
    paste0(parameters[4],
           "[",
            apply(expand.grid(1:cov_data$A,
                              1:cov_data$A), 1, paste, collapse = ","),
            "]")

  beta_params <-
    paste0(parameters[6],
           "[",
           apply(expand.grid(1:cov_data$n_obs,
                             1:cov_data$A), 1, paste, collapse = ","),
           "]")

  E_casesAge_params <-
    paste0(parameters[7],
           "[",
           apply(expand.grid(1:cov_data$n_obs,
                             1:cov_data$A), 1, paste, collapse = ","),
           "]")

  E_deathsAge_params <-
    paste0(parameters[8],
           "[",
            apply(expand.grid(1:cov_data$n_obs,
                              1:cov_data$A), 1, paste, collapse = ","),
          "]")

  E_cases_params  <-
    paste0(parameters[9], "[", 1:cov_data$n_obs, "]")

  E_deaths_params <-
    paste0(parameters[10], "[", 1:cov_data$n_obs, "]")

  out <- round(summary(object,
                       pars = c("lp__",
                                rest_params,
                                cm_params,
                                beta_params,
                                E_casesAge_params,
                                E_deathsAge_params,
                                E_cases_params,
                                E_deaths_params
                                ),
                        ...
                 )$summary, 3)

  return(out)
}
