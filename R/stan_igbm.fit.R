# Part of the Bernadette package for estimating model parameters
#
#' @rdname stan_igbm
#' @export
#'
stan_igbm.fit <-
  function(standata_preprocessed,
           prior_volatility,
           prior_nb_dispersion,
           algorithm,
           nChains,
           nBurn,
           nPost,
           nThin,
           adapt_delta   = NULL,
           max_treedepth = NULL,
           seed,
           ....
          ) {

    algorithm_inference <- match.arg(algorithm)
    nIter               <- nBurn + nPost
    nBurnin             <- nBurn

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
                      prior_rate_nb_dispersion  = prior_rate_nb_dispersion
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

    #---- Call stan() to draw from posterior distribution:
    stanfit <- stanmodels$igbm

    #---- Optimizing:
    if (algorithm_inference == "optimizing") {

      optimizing_args <- list(...)

      if (is.null(optimizing_args$draws)) optimizing_args$draws <- 1000L

      optimizing_args$object <- stanfit
      optimizing_args$data   <- standata
      optimizing_args$seed   <- seed

      out <- do.call(rstan::optimizing, args = optimizing_args)

      check_stanfit(out)

      out$stanfit <- suppressMessages(rstan::sampling(stanfit, data = standata, chains = 0))

      return(out)

    #---- Sampling:
    } else {

      if (algorithm_inference == "sampling") {

         optimizing_args <- list(...)

         if (is.null(optimizing_args$draws)) optimizing_args$draws <- 1000L

         optimizing_args$object <- stanfit
         optimizing_args$data   <- standata
         optimizing_args$seed   <- seed

         fit_optim <- do.call(rstan::optimizing, args = optimizing_args)

         sampler_init <- function(){
           list(pi           = fit_optim$par[names(fit_optim$par) %in% "pi"],
                x0           = fit_optim$par[names(fit_optim$par) %in% "x0"],
                x_noise      = fit_optim$par[grepl("x_noise[",     names(fit_optim$par), fixed = TRUE)],
                L_raw        = fit_optim$par[grepl("L_raw[",       names(fit_optim$par), fixed = TRUE)],
                volatilities = fit_optim$par[grepl("volatilities", names(fit_optim$par), fixed = TRUE)],
                phiD         = fit_optim$par[names(fit_optim$par) %in% "phiD"]
           )
         }

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
                                            init               = sampler_init,
                                            show_messages      = FALSE
                                            )

          stanfit <- do.call(rstan::sampling, sampling_args)

      #---- Variational Bayes:
      } else {

        optimizing_args <- list(...)

        if (is.null(optimizing_args$draws)) optimizing_args$draws <- 1000L

        optimizing_args$object <- stanfit
        optimizing_args$data   <- standata
        optimizing_args$seed   <- seed

        fit_optim <- do.call(rstan::optimizing, args = optimizing_args)

        sampler_init <- function(){
          list(pi           = fit_optim$par[names(fit_optim$par) %in% "pi"],
               x0           = fit_optim$par[names(fit_optim$par) %in% "x0"],
               x_noise      = fit_optim$par[grepl("x_noise[",     names(fit_optim$par), fixed = TRUE)],
               L_raw        = fit_optim$par[grepl("L_raw[",       names(fit_optim$par), fixed = TRUE)],
               volatilities = fit_optim$par[grepl("volatilities", names(fit_optim$par), fixed = TRUE)],
               phiD         = fit_optim$par[names(fit_optim$par) %in% "phiD"]
          )
        }

        # algorithm either "meanfield" or "fullrank"
        stanfit <- rstan::vb(stanfit,
                             data      = standata,
                             pars      = parameters,
                             seed      = seed,
                             init      = sampler_init,
                             algorithm = algorithm_inference,
                             ...)

      }

      #---- Production of output:
      check <- check_stanfit(stanfit)

      if (!isTRUE(check)) return(standata)

      return(base::structure(stanfit,
                             standata   = standata,
                             stanparams = parameters))
    }
  }
