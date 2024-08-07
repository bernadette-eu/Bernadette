#' Estimate the effective reproduction number with the next generation matrix approach
#'
#' @param object An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @param age_distribution_population data.frame;
#' the age distribution of a given population. See \code{aggregate_age_distribution}.
#'
#' @param infectious_period integer;
#' length of infectious period in days. Must be >=1.
#'
#' @return A data.frame which can be visualised using \code{\link[Bernadette]{plot_posterior_rt}}.
#'
#' @references
#' Diekmann, O., Heesterbeek, J., and Roberts, M. (2010). The construction of next-generation matrices for compartmental epidemic models. \emph{J. R. Soc. Interface}, 7, 873–-885.
#'
#' Bouranis, L., Demiris, N. Kalogeropoulos, K. and Ntzoufras, I. (2022). Bayesian analysis of diffusion-driven multi-type epidemic models with application to COVID-19. arXiv: \url{https://arxiv.org/abs/2211.15229}
#'
#' @examples
#' \donttest{
#' # Age-specific mortality/incidence count time series:
#' data(age_specific_mortality_counts)
#' data(age_specific_cusum_infection_counts)
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
#' aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_cusum_infection_counts)
#'
#' # Infection-to-death distribution:
#' ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
#'                          gamma_mean = 24.19231,
#'                          gamma_cv   = 0.3987261)
#'
#' # Posterior sampling:
#'
#' rstan::rstan_options(auto_write = TRUE)
#' chains <- 1
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
#'                       prior_scale_x0              = 1,
#'                       prior_scale_x1              = 1,
#'                       prior_scale_contactmatrix   = 0.05,
#'                       pi_perc                     = 0.1,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = exponential(rate = 1/5),
#'                       algorithm_inference         = "sampling",
#'                       nBurn                       = 10,
#'                       nPost                       = 30,
#'                       nThin                       = 1,
#'                       chains                      = chains,
#'                       adapt_delta                 = 0.6,
#'                       max_treedepth               = 14,
#'                       seed                        = 1)
#'
#' post_rt_summary <- posterior_rt(object                      = igbm_fit,
#'                                 y_data                      = age_specific_mortality_counts,
#'                                 age_distribution_population = aggr_age,
#'                                 infectious_period            = 4)
#'
#' # Visualise the posterior distribution of the effective reproduction number:
#' plot_posterior_rt(post_rt_summary)
#'}
#' @export
#'
posterior_rt <- function(object,
                         y_data,
                         age_distribution_population,
                         infectious_period){

  check <- check_stanfit(object)

  if (!isTRUE(check)) stop("Provide an object of class 'stanfit' using rstan::sampling() or rstan::vb()")

  if("theta_tilde" %in% names(object) ) stop("Perform MCMC sampling using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object)

  cov_data                   <- list()
  cov_data$y_data            <- y_data[,-c(1:5)]
  cov_data$dates             <- y_data$Date
  cov_data$pop_diag          <- 1/(age_distribution_population$PopTotal)
  cov_data$infectious_period <- infectious_period
  age_grps                   <- ncol(y_data[,-c(1:5)])

  if(ncol(posterior_draws$cm_sample) != age_grps) stop( paste0("The number of rows in the age distribution table must be equal to ", age_grps) )

  zero_mat             <- matrix(0L, nrow = age_grps, ncol = age_grps)
  identity_mat         <- diag(age_grps)
  reciprocal_age_distr <- matrix(rep(cov_data$pop_diag, age_grps),   ncol  = age_grps, nrow  = age_grps, byrow = TRUE)
  age_distr            <- matrix(rep(1/cov_data$pop_diag, age_grps), ncol  = age_grps, nrow  = age_grps, byrow = FALSE)
  Q_inverse            <- cov_data$infectious_period * identity_mat

  beta_draws   <- posterior_draws$beta_trajectory
  chain_length <- nrow(beta_draws)
  ts_length    <- dim(beta_draws)[2]
  R_eff_mat    <- matrix(0L, nrow = chain_length, ncol = ts_length)

  for (i in 1:chain_length) {
    for (j in 1:ts_length){

      B_eff_tmp <- matrix( rep(beta_draws[i,,][j,], age_grps),
                           ncol  = age_grps,
                           nrow  = age_grps,
                           byrow = FALSE) *
                   matrix( posterior_draws$cm_sample[i,,],
                           nrow = age_grps,
                           ncol = age_grps) *
                   matrix(rep( posterior_draws$Susceptibles[i,,][j,], age_grps),
                          ncol  = age_grps,
                          nrow  = age_grps,
                          byrow = FALSE) *
                   reciprocal_age_distr

      BQinv_eff_tmp  <- B_eff_tmp %*% Q_inverse
      R_eff_mat[i,j] <- eigen_mat(BQinv_eff_tmp)

    }
  }

  data_eff_repnumber         <- data.frame(Date  = cov_data$dates)
  data_eff_repnumber$median  <- apply(R_eff_mat, 2, median)
  data_eff_repnumber$low0025 <- apply(R_eff_mat, 2, quantile, probs = c(0.025)) # c(0.025)
  data_eff_repnumber$low25   <- apply(R_eff_mat, 2, quantile, probs = c(0.25))  # c(0.025)
  data_eff_repnumber$high75  <- apply(R_eff_mat, 2, quantile, probs = c(0.75))  # c(0.975)
  data_eff_repnumber$high975 <- apply(R_eff_mat, 2, quantile, probs = c(0.975)) # c(0.975)

  return(data_eff_repnumber)

}

#' Plot the estimated effective reproduction number trajectory
#'
#' @param object A data frame from \code{\link[Bernadette]{posterior_rt}}.
#'
#' @param xlab character;
#' Title of x-axis.
#'
#' @param ylab character;
#' Title of y-axis.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{scale_x_date}} and \code{\link[ggplot2]{theme}}.
#'
#' @return A \code{ggplot} object which can be further customised using the \pkg{ggplot2} package.
#'
#' @seealso \code{\link{posterior_rt}}.
#'
#' @examples
#' \donttest{
#' # Age-specific mortality/incidence count time series:
#' data(age_specific_mortality_counts)
#' data(age_specific_cusum_infection_counts)
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
#' aggr_age_ifr <- aggregate_ifr_react(age_distr, ifr_mapping, age_specific_cusum_infection_counts)
#'
#' # Infection-to-death distribution:
#' ditd <- itd_distribution(ts_length  = nrow(age_specific_mortality_counts),
#'                          gamma_mean = 24.19231,
#'                          gamma_cv   = 0.3987261)
#'
#' # Posterior sampling:
#'
#' rstan::rstan_options(auto_write = TRUE)
#' chains <- 1
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
#'                       prior_scale_x0              = 1,
#'                       prior_scale_x1              = 1,
#'                       prior_scale_contactmatrix   = 0.05,
#'                       pi_perc                     = 0.1,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = exponential(rate = 1/5),
#'                       algorithm_inference         = "sampling",
#'                       nBurn                       = 10,
#'                       nPost                       = 30,
#'                       nThin                       = 1,
#'                       chains                      = chains,
#'                       adapt_delta                 = 0.6,
#'                       max_treedepth               = 14,
#'                       seed                        = 1)
#'
#' post_rt_summary <- posterior_rt(object                      = igbm_fit,
#'                                 y_data                      = age_specific_mortality_counts,
#'                                 age_distribution_population = aggr_age,
#'                                 infectious_period            = 4)
#'
#' # Visualise the posterior distribution of the effective reproduction number:
#' plot_posterior_rt(post_rt_summary)
#'}
#' @export
#'
plot_posterior_rt <- function(object,
                              xlab = NULL,
                              ylab = NULL,
                              ...
){

  if (is.null(xlab)) xlab <- "Epidemiological Date"
  if (is.null(ylab)) ylab <- "Effective reproduction number"

  ret <-
    ggplot2::ggplot(object) +
    ggplot2::geom_line(ggplot2::aes(x     = Date,
                                    y     = median,
                                    color = "Median"),
                                    size  = 1.3) +
    ggplot2::geom_ribbon(aes(x    = Date,
                             ymin = low25,
                             ymax = high75,
                             fill = "50% CrI"),
                         alpha = 0.6) +
    ggplot2::geom_hline(yintercept = 1, color = "black") +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::scale_x_date(...) +
    ggplot2::scale_y_continuous(limits = c(0,     max(object$high75)*1.1),
                                breaks = c(seq(0, max(object$high75)*1.1, 0.2)) ) +
    ggplot2::scale_fill_manual(values = c("50% CrI" = "gray40") ) +
    ggplot2::scale_colour_manual(name = '', values = c('Median' = "black")) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "bottom",
                   legend.title    = ggplot2::element_blank(),
                   ...)

  ret

}
