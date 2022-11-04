#' Single-diffusion multi-type SEEIIR transmission model
#'
#' Function to implement the Bayesian single-diffusion multi-type SEEIIR transmission model with Stan.
#'
#' @param standata A named `list` or `environment` providing the data for the model or a character vector for all the names of objects used as data. See \link[rstan]{sampling}.
#'
#' @param ... Arguments passed to `rstan::sampling` (e.g. iter, chains). See \link[rstan]{sampling}.
#'
#' @return An object of class `stanfit` returned by `rstan::sampling`
#'
#' @export
#'
seeiir_sbm <- function(standata, ...) {
  out <- rstan::sampling(stanmodels$seeiir_sbm,
                         data = standata,
                         ...)
  return(out)
}
