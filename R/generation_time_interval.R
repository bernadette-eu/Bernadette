#' Generation interval distribution
#'
#' Function to calculate the generation interval distribution
#'
#' @param ts_length numeric; timepoints (days).
#'
#' @param latency_duration numeric; mean duration of the latent period (in days). Must be >=1.
#'
#' @param infectiousness_duration numeric; mean duration of the infectious period (in days). Must be >=1.
#'
#' @param latent_stages numeric; number of latent substages. Must be >=1.
#'
#' @param infectious_stages numeric; number of infectious substages. Must be >=1.
#'
#' @param erlang_model logical; should an Erlang distributed transmission model be used?
#'
#' @references
#' Champredon, D., Dushoff, J., and Earn, D. (2018). Equivalence of the Erlang-Distributed
#' SEIR Epidemic Model and the Renewal Equation. SIAM Journal on Applied Mathematics,
#' 78(6):3258–3278.
#'
#' @return A vector of length \emph{ts_length}.
#'
#' @examples
#'
#' \dontrun{
#' ditd <- gti_distribution(ts_length  = 100,
#'                          latency_duration,
#'                          infectiousness_duration,
#'                          latent_stages     = 2,
#'                          infectious_stages = 2,
#'                          erlang_model      = TRUE
#'}
#'
#' @export
#'
gti_distribution <- function(ts_length,
                             latency_duration,       # 1/sigma days
                             infectiousness_duration,# 1/gamma days
                             latent_stages     = 2,
                             infectious_stages = 2,
                             erlang_model      = TRUE
){


  lower_incomplete_gamma <- function(kappa, x){
   # Source 1: https://docs.sympy.org/latest/modules/functions/special.html#sympy.functions.special.gamma_functions.lowergamma
   # Source 2: https://search.r-project.org/CRAN/refmans/expint/html/gammainc.html
    output <- base::gamma(kappa) - base::gamma(kappa) * stats::pgamma(x, kappa, rate = 1, lower.tail = FALSE)

   return(output)

  }# End function

  C_bar <- function(kappa,
                    alpha,
                    latency,
                    infectiousness,
                    latent_stages,
                    infectious_stages){

    temp_sum <- 0
    for (i in 0:(latent_stages - 1)) temp_sum <- temp_sum +
                                                  choose(latent_stages - i + kappa - 3, kappa - 2) *
                                                  ( ( alpha / (latency*latent_stages) )^(i+1) )

    output <- ( (-1/alpha)^(k-1) ) *
              (1/(infectiousness * infectious_stages)) *
              temp_sum

    return(output)

  }# End function

  B_bar <- function(kappa,
                    alpha,
                    latency,
                    infectiousness,
                    latent_stages,
                    infectious_stages){

    temp_sum <- 0

    for (i in 0:(kappa - 3)) temp_sum <- temp_sum +
                                         choose(latent_stages + i - 1, i) *
                                         ( ((-infectiousness*infectious_stages) / alpha )^i )

    output <- (1 / ( (infectiousness*infectious_stages)^kappa ) )* temp_sum

    return(output)

  }# End function

  A_bar <- function(kappa,
                    alpha,
                    latency,
                    infectiousness,
                    latent_stages,
                    infectious_stages){

    output <- ( (-1)^kappa ) *
              choose(kappa + latent_stages - 3, kappa - 2) *
              ( alpha^(1 - kappa) ) *
              (- (1 / (infectiousness*infectious_stages)) +
                 (alpha / ( (infectiousness*infectious_stages)^2) ) +
                 (1/(latency*latent_stages))
              )

    return(output)

  }# End function

  K_mn <- function(alpha,
                   latency,
                   infectiousness,
                   latent_stages,
                   infectious_stages){

    temp_sum <- 0

    for (k in 2:infectious_stages){

      temp_sum <- temp_sum +
                  ( (infectiousness*infectious_stages)^(k-1) )*
                  (A_bar(k,
                         alpha             = alpha,
                         latency           = latency,
                         infectiousness    = infectiousness,
                         latent_stages     = latent_stages,
                         infectious_stages = infectious_stages) +
                   B_bar(k,
                         alpha             = alpha,
                         latency           = latency,
                         infectiousness    = infectiousness,
                         latent_stages     = latent_stages,
                         infectious_stages = infectious_stages) +
                   C_bar(k,
                         alpha             = alpha,
                         latency           = latency,
                         infectiousness    = infectiousness,
                         latent_stages     = latent_stages,
                         infectious_stages = infectious_stages)
                )
    }# End for

    output <- ( 1 / (infectiousness*infectious_stages) ) *
              ( ( alpha / (latency*latent_stages) )^latent_stages ) +
              temp_sum

    return(output)

  }# End function

  psi_kt <- function(t,
                     kappa,
                     alpha,
                     latent_stages){

    temp_sum <- 0

    for ( l in 1:(latent_stages - 1) ) {
      temp_sum <- temp_sum +
                  choose(latent_stages - l + kappa - 2, kappa - 1) *
                  ( 1/factorial(l) ) *
                  lower_incomplete_gamma(l + 1, alpha*t)
    }# End for

    output <- (1 / alpha) * temp_sum

    return(output)

  }# End function

  C_kt <- function(k, t, alpha, latency, latent_stages){

    output <- ( (-1)^(k + 1)) *
              ( psi_kt(t,
                       kappa         = k - 1,
                       alpha         = alpha,
                       latent_stages = latent_stages) /
                ( alpha^(k-2) ) )

    return(output)

  }# End function

  B_kt <- function(k, t, alpha, latent_stages){

    temp_sum <- 0

    for ( i in 0:(k - 3) ) {
      temp_sum <- temp_sum +
                  ((-1)^i) *
                  ( 1/(alpha^i) ) *
                  choose(latent_stages + i - 1, i) *
                  ( ( t^(k - 1 -i) ) / factorial(k - 1 - i) )
    }# End for

    return(temp_sum)

  }# End function

  A_kt <- function(k, t, alpha, latent_stages){

    output <- ( (-1)^k ) *
              choose(k + latent_stages - 3, k - 2) *
              ( alpha^(1-k) ) *
              (-1 + alpha*t + exp(-alpha*t))

    return(output)

  }# End function

  latency        <- 1/latency_duration
  infectiousness <- 1/infectiousness_duration

  if( latency < 0 ) stop("Ensure that latency > 0.")
  if( infectiousness < 0 ) stop("Ensure that infectiousness > 0.")
  if( latent_stages < 0 ) stop("Ensure that latent_stages >= 0.")
  if( infectious_stages < 1 ) stop("Ensure that infectious_stages >= 1.")

  gti_output <- rep(0, ts_length)

  for(t in 1:ts_length) {

    if (erlang_model == FALSE){

      #---- Standard SEIR model:
      if(latency != infectiousness){

        gti_output[t] <- ( (latency*infectiousness) / (latency - infectiousness) ) * ( exp(latency*t) - exp(-infectiousness*t) )

      } else {

        gti_output[t] <- ( (infectiousness^2) * t) * exp(-infectiousness*t)

      }# End if

    } else {

      #---- SI^n R model:
      if(latent_stages == 0){ # Equation 3.4

        temp_sum <- 0

        for (k in 0:(infectious_stages - 1)) temp_sum <- temp_sum + ((infectious_stages * infectiousness * t)^k)/factorial(k)

        gti_output[t] <- infectiousness * exp(-infectious_stages * infectiousness * t) * temp_sum

      #---- S E^m I^n R model, Equation 3.10:
      } else if ( latent_stages >= 1 & ( (latency*latent_stages) == (infectiousness*infectious_stages) ) ){

        temp_sum <- 0

        for (k in 0:(infectious_stages - 1)) temp_sum <- temp_sum + ( (infectious_stages * infectiousness * t)^(latent_stages + k) ) / factorial(latent_stages + k)

        gti_output[t] <- infectiousness * exp(-infectious_stages * infectiousness * t) * temp_sum

      #---- S E^m I^n R model, Equation 3.15:
      } else if ( latent_stages >= 1 & ( (latency*latent_stages) != (infectiousness*infectious_stages) )  ) {

        alpha <- latency*latent_stages - infectiousness*infectious_stages

        if (infectious_stages == 1 ){

          gti_output[t] <- ( infectiousness / factorial(latent_stages - 1) ) *
                           ( ( latency*latent_stages / alpha )^latent_stages ) *
                           lower_incomplete_gamma(latent_stages, alpha*t) *
                           exp(-infectiousness * t)

        } else if (infectious_stages >= 2) {

          temp_sum <- 0

          for (k in 2:infectious_stages) {

            temp_sum <- temp_sum +
                        ( (infectiousness*infectious_stages)^(k-1) ) *
                          (
                            A_kt(k = k, t = t, alpha = alpha, latent_stages = latent_stages) +
                            B_kt(k = k, t = t, alpha = alpha, latent_stages = latent_stages) +
                            C_kt(k = k, t = t, alpha = alpha, latent_stages = latent_stages)
                          )
          }# End for

          gti_output[t] <- ( exp(-infectiousness * infectious_stages * t) /
                             K_mn(alpha             = alpha,
                                  latency           = latency,
                                  infectiousness    = infectiousness,
                                  latent_stages     = latent_stages,
                                  infectious_stages = infectious_stages) )  *
                            ((lower_incomplete_gamma(latent_stages, alpha*t) / factorial(latent_stages - 1) ) +
                             temp_sum )
        }# End if
      }# End if
    }# End if
  }# End for

  return(gti_output)

}# End function
