#' Summary of stanigbm posterior output
#'
#' This function summarizes the MCMC output for \code{stanigbm} objects.
#'
#' @param object an \code{R} object of class \code{stanigbm}.
#'
#' @param ... Additional arguments, to be passed to lower-level functions. See \link[rstan]{summary-methods}.
#'
#' @export
#' @method summary stanigbm

summary.stanigbm <- function(object, ...) {

  validate_stanigbm_object(object)

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

  rest_params <-
    c(parameters[1],
      parameters[2],
      paste0(parameters[3],"[", 1:object$standata$A,"]"),
      parameters[5],
      )

  cm_params <-
    paste0(parameters[4],
           "[",
            apply(expand.grid(1:object$standata$A,
                              1:object$standata$A), 1, paste, collapse = ","),
            "]")

  beta_params <-
    paste0(parameters[6],
           "[",
           apply(expand.grid(1:object$standata$n_obs,
                             1:object$standata$A), 1, paste, collapse = ","),
           "]")

  E_casesAge_params <-
    paste0(parameters[7],
           "[",
           apply(expand.grid(1:object$standata$n_obs,
                             1:object$standata$A), 1, paste, collapse = ","),
           "]")

  E_deathsAge_params <-
    paste0(parameters[8],
           "[",
            apply(expand.grid(1:object$standata$n_obs,
                              1:object$standata$A), 1, paste, collapse = ","),
          "]")

  E_cases_params  <-
    paste0(parameters[9], "[", 1:object$standata$n_obs, "]")

  E_deaths_params <-
    paste0(parameters[10], "[", 1:object$standata$n_obs, "]")

  Susceptibles_params <-
    paste0(parameters[11],
           "[",
           apply(expand.grid(1:object$standata$n_obs,
                             1:object$standata$A), 1, paste, collapse = ","),
           "]")

  out <- summary(object$stanfit,
                 pars = c("lp__",
                          rest_params,
                          cm_params,
                          beta_params,
                          E_casesAge_params,
                          E_deathsAge_params,
                          E_cases_params,
                          E_deaths_params,
                          Susceptibles_params),
                 ...)

  return(out)
}
