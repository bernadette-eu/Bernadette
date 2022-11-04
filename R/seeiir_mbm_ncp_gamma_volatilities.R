#' Multi-diffusion multi-type SEEIIR transmission model
#'
#' Function to implement the Bayesian multi-diffusion multi-type SEEIIR transmission model with Stan, assuming Gamma distributed prior distributions for the age-specific volatilities and a non-centered parameterisation of the latent diffusion path.
#'
#' @param standata A named `list` or `environment` providing the data for the model or a character vector for all the names of objects used as data. See \link[rstan]{sampling}.
#'
#' @param ... Arguments passed to `rstan::sampling` (e.g. iter, chains). See \link[rstan]{sampling}.
#'
#' @return An object of class `stanfit` returned by `rstan::sampling`
#'
#' @export
#'
seeiir_mbm_ncp_gamma_volatilities <- function(standata, ...) {
  out <- rstan::sampling(stanmodels$seeiir_mbm_ncp_gamma_volatilities,
                         data = standata,
                         ...)
  return(out)
}
