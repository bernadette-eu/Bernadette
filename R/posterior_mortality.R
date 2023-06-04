#' Summarize the posterior distribution of the mortality counts
#'
#' @param object An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @return
#' #' A named list with elements \code{Age_specific} and \code{Aggregated} which can be visualised using \code{\link[Bernadette]{plot_posterior_mortality}}.
#'
#' @references
#' Bouranis, L., Demiris, N. Kalogeropoulos, K. and Ntzoufras, I. (2022). Bayesian analysis of diffusion-driven multi-type epidemic models with application to COVID-19. arXiv: \url{https://arxiv.org/abs/2211.15229}
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
#'
#' rstan_options(auto_write = TRUE)
#' chains <- 2
#' options(mc.cores = chains)
#'
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       itd_distr                   = ditd,
#'                       incubation_period           = 3,
#'                       infectious_period           = 4,
#'                       likelihood_variance_type    = "linear",
#'                       ecr_changes                 = 7,
#'                       prior_scale_x0              = 0.5,
#'                       prior_scale_contactmatrix   = 0.05,
#'                       pi_perc                     = 0.1,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = exponential(rate = 1/5),
#'                       algorithm_inference         = "sampling",
#'                       nBurn                       = 5,
#'                       nPost                       = 10,
#'                       nThin                       = 1,
#'                       chains                      = chains,
#'                       adapt_delta                 = 0.8,
#'                       max_treedepth               = 16,
#'                       seed                        = 1)
#'
#' post_mortality_summary <- posterior_mortality(object = igbm_fit,
#'                                               y_data = age_specific_mortality_counts)
#'
#' # Visualise the posterior distribution of the mortality counts:
#' plot_posterior_mortality(post_mortality_summary, type = "age-specific")
#' plot_posterior_mortality(post_mortality_summary, type = "aggregated")
#'}
#' @export
#'
posterior_mortality <- function(object, y_data){

  check <- check_stanfit(object)

  if (!isTRUE(check)) stop("Provide an object of class 'stanfit' using rstan::sampling() or rstan::vb()")

  if("theta_tilde" %in% names(object) ) stop("Perform MCMC sampling using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object)
  cov_data        <- list()
  cov_data$y_data <- y_data[,-c(1:5)]
  cov_data$dates  <- y_data$Date
  cov_data$A      <- ncol(y_data[,-c(1:5)])

  #---- Age-specific:
  output_age_cols     <- c("Date", "Group", "median", "low", "high", "low25", "high75")
  output_age           <- data.frame(matrix(ncol = length(output_age_cols), nrow = 0))
  colnames(output_age) <- output_age_cols

  for (i in 1:cov_data$A){

    fit_age           <- posterior_draws$E_deathsByAge[,,i]
    dt_deaths_age_grp <- data.frame(Date  = cov_data$dates,
                                    Group = rep( colnames(cov_data$y_data)[i], length(cov_data$dates) ) )

    dt_deaths_age_grp$median <- apply(fit_age, 2, median)
    dt_deaths_age_grp$low    <- apply(fit_age, 2, quantile, probs = c(0.025))
    dt_deaths_age_grp$high   <- apply(fit_age, 2, quantile, probs = c(0.975))
    dt_deaths_age_grp$low25  <- apply(fit_age, 2, quantile, probs = c(0.25))
    dt_deaths_age_grp$high75 <- apply(fit_age, 2, quantile, probs = c(0.75))

    output_age <- rbind(output_age, dt_deaths_age_grp)
  }

  #---- Aggregated:
  fit_aggregated           <- posterior_draws$E_deaths

  output_aggregated        <- data.frame(Date = cov_data$dates)
  output_aggregated$median <- apply(fit_aggregated, 2, median)
  output_aggregated$low    <- apply(fit_aggregated, 2, quantile, probs = c(0.025))
  output_aggregated$high   <- apply(fit_aggregated, 2, quantile, probs = c(0.975))
  output_aggregated$low25  <- apply(fit_aggregated, 2, quantile, probs = c(0.25))
  output_aggregated$high75 <- apply(fit_aggregated, 2, quantile, probs = c(0.75))

  output <- list(Age_specific = output_age,
                 Aggregated   = output_aggregated)

  return(output)
}

#' Plot the posterior distribution of the mortality counts
#'
#' @param object
#' A dataframe from \code{\link[Bernadette]{posterior_mortality}}.
#'
#' @param type character;
#' Plot the output for the 'age-specific' mortality counts or the 'aggregated' mortality counts.
#'
#' @param xlab character;
#' title of x-axis.
#'
#' @param ylab character;
#' title of y-axis.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{scale_x_date}}.
#'
#' @return A \code{ggplot} object which can be further customised using the \pkg{ggplot2} package.
#'
#' @seealso \code{\link{posterior_mortality}}.
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
#'
#' rstan_options(auto_write = TRUE)
#' chains <- 2
#' options(mc.cores = chains)
#'
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       itd_distr                   = ditd,
#'                       incubation_period           = 3,
#'                       infectious_period           = 4,
#'                       likelihood_variance_type    = "linear",
#'                       ecr_changes                 = 7,
#'                       prior_scale_x0              = 0.5,
#'                       prior_scale_contactmatrix   = 0.05,
#'                       pi_perc                     = 0.1,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = exponential(rate = 1/5),
#'                       algorithm_inference         = "sampling",
#'                       nBurn                       = 5,
#'                       nPost                       = 10,
#'                       nThin                       = 1,
#'                       chains                      = chains,
#'                       adapt_delta                 = 0.8,
#'                       max_treedepth               = 16,
#'                       seed                        = 1)
#'
#' post_mortality_summary <- posterior_mortality(object = igbm_fit,
#'                                               y_data = age_specific_mortality_counts)
#'
#' # Visualise the posterior distribution of the mortality counts:
#' plot_posterior_mortality(post_mortality_summary, type = "age-specific")
#' plot_posterior_mortality(post_mortality_summary, type = "aggregated")
#'}
#' @export
#'
plot_posterior_mortality <- function(object,
                                     type = c("age-specific", "aggregated"),
                                     xlab = NULL,
                                     ylab = NULL,
                                     ...){

  aggr_type <- match.arg(type)

  if (is.null(xlab)) xlab <- "Epidemiological Date"
  if (is.null(ylab)) ylab <- "New daily mortality counts"

  if (aggr_type %nin% type){

    stop("Please select a type of aggregation from ('age-specific', 'aggregated').")

  } else if (aggr_type == "age-specific"){

    ret <-
      ggplot2::ggplot(object$Age_specific) +
      ggplot2::facet_wrap(. ~ Group, scales = "free_y") +
      ggplot2::geom_line(ggplot2::aes(x     = Date,
                                      y     = median,
                                      color = "Median"),
                         size  = 1.3) +
      ggplot2::geom_ribbon(ggplot2::aes(x    = Date,
                                        ymin = low25,
                                        ymax = high75,
                                        fill = "50% CrI"),
                           alpha = 0.5) +
      ggplot2::geom_ribbon(ggplot2::aes(x    = Date,
                                        ymin = low,
                                        ymax = high,
                                        fill = "95% CrI"),
                           alpha = 0.5) +
      ggplot2::labs(x = xlab, y = ylab) +
      ggplot2::scale_x_date(...) +
      ggplot2::scale_fill_manual(values = c("50% CrI" = "gray70", "95% CrI" = "gray40")) +
      ggplot2::scale_colour_manual(name = '', values = c('Median' = "black")) +
      ggplot2::theme_bw() +
      ggplot2::theme(legend.position = "bottom",
                     legend.title    = ggplot2::element_blank())

  } else if (aggr_type == "aggregated"){

    ret <-
        ggplot2::ggplot(object$Aggregated) +
        ggplot2::geom_line(ggplot2::aes(x     = Date,
                                        y     = median,
                                        color = "Median"),
                           size  = 1.3) +
      ggplot2::geom_ribbon(ggplot2::aes(x    = Date,
                                        ymin = low25,
                                        ymax = high75,
                                        fill = "50% CrI"),
                           alpha = 0.5) +
      ggplot2::geom_ribbon(ggplot2::aes(x    = Date,
                                        ymin = low,
                                        ymax = high,
                                        fill = "95% CrI"),
                           alpha = 0.5) +
      ggplot2::labs(x = xlab, y = ylab) +
      ggplot2::scale_x_date(...) +
      ggplot2::scale_fill_manual(values = c("50% CrI" = "gray70", "95% CrI" = "gray40")) +
      ggplot2::scale_colour_manual(name = '', values = c('Median' = "black")) +
      ggplot2::theme_bw() +
      ggplot2::theme(legend.position = "bottom",
                     legend.title    = ggplot2::element_blank())
  }

  ret
}
