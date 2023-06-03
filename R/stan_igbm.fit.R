# Part of the Bernadette package for estimating model parameters
#
#' @rdname stan_igbm
#'
#' @param standata_preprocessed
#' A named list providing the data for the model. See \code{\link[rstan]{sampling}}.
#'
#' @param algorithm
#' See \code{algorithm} in \link[Bernadette]{stan_igbm}.
#'
#' @return An object of S4 class \emph{stanfit} representing the fitted results. Slot mode for this object indicates if the sampling is done or not.
#'
#' @export
#'
stan_igbm.fit <-
  function(standata_preprocessed,
           prior_volatility,
           prior_nb_dispersion,
           algorithm,
           nBurn,
           nPost,
           nThin,
           adapt_delta   = NULL,
           max_treedepth = NULL,
           seed,
           ...
          ) {

    nIter   <- nBurn + nPost
    nBurnin <- nBurn

    # standata_preprocessed <- list()
    # standata_preprocessed$ecr_changes <- 7
    # standata_preprocessed$n_obs <- 210
    # standata_preprocessed$A <- 3

    n_changes    <- ceiling(standata_preprocessed$n_obs / standata_preprocessed$ecr_changes)
    n_remainder  <- (standata_preprocessed$n_obs - (n_changes-1)*standata_preprocessed$ecr_changes)
    L_raw_length <- (standata_preprocessed$A * (standata_preprocessed$A + 1)) / 2

    #(n_changes-1)*standata_preprocessed$ecr_changes + n_remainder

    #---- Useless assignments to pass R CMD check
    prior_dist_volatility       <- prior_dist_nb_dispersion <-
      prior_mean_volatility     <- prior_scale_volatility   <-
      prior_df_volatility       <- prior_shape_volatility   <-
      prior_rate_volatility     <- prior_mean_nb_dispersion <-
      prior_scale_nb_dispersion <- prior_df_nb_dispersion   <-
      prior_shape_nb_dispersion <- prior_rate_nb_dispersion <- NULL

    ok_dists <- nlist("normal",
                      student_t = "t",
                      "cauchy",
                      "gamma",
                      "exponential")

    #---- Prior distribution for the volatilities (handle_prior() from priors.R):
    prior_params_volatilities <- handle_prior(prior_volatility, ok_dists = ok_dists)
    names(prior_params_volatilities) <- paste0(names(prior_params_volatilities),  "_volatility")

    for (i in names(prior_params_volatilities)) assign(i, prior_params_volatilities[[i]])

    #---- Prior distribution for the dispersion (handle_prior() from priors.R):
    prior_params_dispersion <- handle_prior(prior_nb_dispersion, ok_dists = ok_dists)
    names(prior_params_dispersion) <- paste0(names(prior_params_dispersion),  "_nb_dispersion")

    for (i in names(prior_params_dispersion)) assign(i, prior_params_dispersion[[i]])

    #---- Create entries in the data block of the .stan file:
    standata <- c(standata_preprocessed,
                  nlist(
                      prior_dist_volatility     = prior_dist_volatility,
                      prior_mean_volatility     = prior_mean_volatility,
                      prior_scale_volatility    = prior_scale_volatility,
                      prior_df_volatility       = prior_df_volatility,
                      prior_shape_volatility    = prior_shape_volatility,
                      prior_rate_volatility     = prior_rate_volatility,
                      prior_dist_nb_dispersion  = prior_dist_nb_dispersion,
                      prior_mean_nb_dispersion  = prior_mean_nb_dispersion,
                      prior_scale_nb_dispersion = prior_scale_nb_dispersion,
                      prior_df_nb_dispersion    = prior_df_nb_dispersion,
                      prior_shape_nb_dispersion = prior_shape_nb_dispersion,
                      prior_rate_nb_dispersion  = prior_rate_nb_dispersion,
                      n_changes                 = n_changes,
                      n_remainder               = n_remainder,
                      L_raw_length              = L_raw_length
                      ))

    #---- List of parameters that will be monitored:
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
                    "Susceptibles",
                    "log_lik",
                    "deviance")

    #---- Call Stan to draw from posterior distribution:
    stanfit <- stanmodels$igbm

    #---- Optimizing:
    if (algorithm == "optimizing") {

      optimizing_args <- list(...)

      if (is.null(optimizing_args$draws)) optimizing_args$draws <- 1000L

      optimizing_args$object <- stanfit
      optimizing_args$data   <- standata
      optimizing_args$seed   <- seed

      out <- do.call(rstan::optimizing, args = optimizing_args)

      check_stanfit(out)

      return(out)

    #---- Sampling:
    } else {

      if (algorithm == "sampling") {

         sampling_args <- set_sampling_args(object             = stanfit,
                                            user_dots          = list(...),
                                            user_adapt_delta   = adapt_delta,
                                            user_max_treedepth = max_treedepth,
                                            data               = standata,
                                            pars               = parameters,
                                            warmup             = nBurnin,
                                            iter               = nIter,
                                            thin               = nThin,
                                            seed               = seed,
                                            show_messages      = FALSE
                                            )

          stanfit <- do.call(rstan::sampling, sampling_args)

      #---- Variational Bayes:
      } else {

        # Algorithm either "meanfield" or "fullrank":
        stanfit <- rstan::vb(stanfit,
                             data      = standata,
                             pars      = parameters,
                             seed      = seed,
                             algorithm = algorithm,
                             ...)
      }

      #---- Production of output:
      check <- check_stanfit(stanfit)

      if (!isTRUE(check)) return(standata)

      return(stanfit)
    }
  }
