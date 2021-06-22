#' Distribution of the time between infection and death
#'
#' Function to discretize the infection-to-death distribution
#'
#' @param ts_length numeric; time from infection to death (days).
#'
#' @param gamma_mean numeric; mean of a gamma distribution, for a given shape and rate. See also \code{\link[stats]{GammaDist}}.
#'
#' @param gamma_cv numeric; coefficient of variation of a gamma distribution, for a given shape and rate. See also \code{\link[stats]{GammaDist}}.
#'
#' @param gamma_shape numeric; shape parameter of a gamma distribution. See also \code{\link[stats]{GammaDist}}.
#'
#' @param gamma_rate numeric; rate parameter of a gamma distribution. See also \code{\link[stats]{GammaDist}}.
#'
#' @references
#' Flaxman et al (2020). Estimating the effects of non-pharmaceutical interventions on COVID-19 in Europe.
#' Nature, 584, 257–261.
#'
#' @return A vector of length \emph{ts_length}.
#'
#' @examples
#'
#' \dontrun{
#' ditd <- discretize_itd(ts_length  = 100,
#'                        gamma_mean = 24.19231,
#'                        gamma_cv   = 0.3987261
#'}
#'
#' @export
#'
discretize_itd <- function(ts_length,
                           gamma_mean = 24.19231,
                           gamma_cv   = 0.3987261,
                           gamma_shape= 6.29,
                           gamma_rate = 0.26
){

  if ( ( is.numeric(gamma_mean)  & is.numeric(gamma_cv) &
        (is.null(gamma_shape)    & is.null(gamma_rate) ) ) |
       ( is.numeric(gamma_mean)  & is.numeric(gamma_cv) &
        (is.numeric(gamma_shape) & is.numeric(gamma_rate) ) )
  ){

    shape <- 1/(gamma_cv^2)
    rate  <- shape/gamma_mean

  } else if( is.null(gamma_mean)      & is.null(gamma_cv) &
             (is.numeric(gamma_shape) & is.numeric(gamma_rate) ) ){

    shape <- gamma_shape
    rate  <- gamma_rate

  }  else if(is.null(gamma_mean)   & is.null(gamma_cv) &
             (is.null(gamma_shape) & is.null(gamma_rate) )){

    stop("Either the pair (gamma_mean, gamma_cv) or the pair (gamma_shape, gamma_rate) must be numeric.")
  }

  if (shape <= 0 ) stop("The shape parameter is not positive.")
  if (rate  <= 0 ) stop("The rate parameter is not positive.")

  infection_death    <- rep(0, ts_length)
  infection_death[1] <- stats::pgamma(1.5, shape = shape, rate = rate) -
                        stats::pgamma(0,   shape = shape, rate = rate)

  for(i in 2:ts_length) {
    infection_death[i] <- stats::pgamma(i+.5, shape = shape, rate = rate) -
                          stats::pgamma(i-.5, shape = shape, rate = rate)
  }

  return(infection_death)

}# End function
