#' Estimate the age-specific transmission rate
#'
#' @param object
#' An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @return
#' A data.frame which can be visualised using \code{\link[Bernadette]{plot_posterior_transmrate}}.
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
#' post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
#'                                                 y_data = age_specific_mortality_counts)
#'
#' # Visualise the posterior distribution of the age-specific transmission rate:
#' plot_posterior_transmrate(post_transmrate_summary)
#'}
#' @export
#'
posterior_transmrate <- function(object, y_data){

  check <- check_stanfit(object)

  if (!isTRUE(check)) stop("Provide an object of class 'stanfit' using rstan::sampling() or rstan::vb()")

  if("theta_tilde" %in% names(object) ) stop("Perform MCMC sampling using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object)

  cov_data        <- list()
  cov_data$y_data <- y_data[,-c(1:5)]
  cov_data$dates  <- y_data$Date
  age_grps        <- ncol(cov_data$y_data)

  if(ncol(posterior_draws$cm_sample) != age_grps) stop( paste0("The number of rows in the age distribution table must be equal to ", age_grps) )

  beta_draws   <- posterior_draws$beta_trajectory
  chain_length <- nrow(beta_draws)
  ts_length    <- dim(beta_draws)[2]

  data_transmission_rate_cols      <- c("Date", "Group", "median", "low0025", "low25", "high75", "high975")
  data_transmission_rate           <- data.frame(matrix(ncol = length(data_transmission_rate_cols), nrow = 0))
  colnames(data_transmission_rate) <- data_transmission_rate_cols

  for (k in 1:age_grps){

    trans_rate_temp          <- matrix(0L, nrow = chain_length, ncol = ts_length)
    data_trans_rate_age_grp  <- data.frame(Date  = cov_data$dates,
                                           Group = rep( colnames(cov_data$y_data)[k], length(cov_data$dates)
                                           ))

    for (j in 1:ts_length) trans_rate_temp[,j] <- beta_draws[,j,k] * posterior_draws$cm_sample[,k,k]

    data_trans_rate_age_grp$median  <- apply(trans_rate_temp, 2, median)
    data_trans_rate_age_grp$low0025 <- apply(trans_rate_temp, 2, quantile, probs = c(0.025)) # c(0.025)
    data_trans_rate_age_grp$low25   <- apply(trans_rate_temp, 2, quantile, probs = c(0.25))  # c(0.025)
    data_trans_rate_age_grp$high75  <- apply(trans_rate_temp, 2, quantile, probs = c(0.75))  # c(0.975)
    data_trans_rate_age_grp$high975 <- apply(trans_rate_temp, 2, quantile, probs = c(0.975)) # c(0.975)

    data_transmission_rate <- rbind(data_transmission_rate,  data_trans_rate_age_grp)

  }# End for

  return(data_transmission_rate)
}

#' Plot the estimated age-specific transmission rate
#'
#' @param object A dataframe from \code{\link[Bernadette]{posterior_transmrate}}.
#'
#' @param xlab character; Title of x-axis.
#'
#' @param ylab character; Title of y-axis.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{facet_wrap}}, \code{\link[ggplot2]{scale_x_date}} and \code{\link[ggplot2]{theme}}.
#'
#' @return A \code{ggplot} object which can be further customised using the \pkg{ggplot2} package.
#'
#' @seealso \code{\link{posterior_transmrate}}.
#'
#' @examples
#' \donttest{
#' if (.Platform$OS.type != "windows" || .Platform$r_arch != "i386") {
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
#' post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
#'                                                 y_data = age_specific_mortality_counts)
#'
#' # Visualise the posterior distribution of the age-specific transmission rate:
#' plot_posterior_transmrate(post_transmrate_summary)
#' }
#'}
#' @export
#'
plot_posterior_transmrate <- function(object,
                                      xlab = NULL,
                                      ylab = NULL,
                                      ...
){


  if (is.null(xlab)) xlab <- "Epidemiological Date"
  if (is.null(ylab)) ylab <- "Transmission rate"

  ret <-
    ggplot2::ggplot(object) +
    ggplot2::facet_wrap(. ~ Group, ...) +
    ggplot2::geom_line(ggplot2::aes(x     = Date,
                                    y     = median,
                                    color = "Median"),
                                size  = 1.3) +
    ggplot2::geom_ribbon(ggplot2::aes(x    = Date,
                                      ymin = low25,
                                      ymax = high75,
                                      fill = "50% CrI"),
                                   alpha = 0.6) +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::scale_x_date(...) +
    ggplot2::scale_fill_manual(values = c("50% CrI" = "gray40")) +
    ggplot2::scale_colour_manual(name = '', values = c('Median' = "black")) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom",
                   legend.title    = ggplot2::element_blank(),
                   ...)

  ret
}
