#' Plot the posterior contact matrix
#'
#' @param object An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{theme}}.
#'
#' @return A \code{grid.arrange} object which can be further customised using the \pkg{gridExtra} package.
#'
#' @references
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
#' # Visualise the posterior distribution of the random contact matrix:
#' plot_posterior_cm(object = igbm_fit,
#'                   y_data = age_specific_mortality_counts)
#'}
#' @export
#'
plot_posterior_cm <- function(object, y_data, ...){

  check <- check_stanfit(object)

  if (!isTRUE(check)) stop("Provide an object of class 'stanfit' using rstan::sampling() or rstan::vb()")

  if("theta_tilde" %in% names(object) ) stop("Perform MCMC sampling using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object)
  age_grps        <- ncol(y_data[,-c(1:5)])

  if(ncol(posterior_draws$cm_sample) != age_grps) stop( paste0("The number of rows in the age distribution table must be equal to ", age_grps) )

  niters       <- nrow(posterior_draws[["cm_sample"]])
  plot_cm_list <- list()
  plot_cm_indx <- 1

  for (i in 1:age_grps){
    for (j in 1:age_grps){

      dt_cm_post <- data.frame(Posterior = posterior_draws[["cm_sample"]][,i, j])

      p <- ggplot2::ggplot(dt_cm_post,
                           ggplot2::aes(x = Posterior),
                           fill = "gray") +
        ggplot2::geom_density(alpha = 0.8, fill = "gray") +
        ggplot2::scale_x_continuous(breaks = scales::pretty_breaks(n = 2)) +
        ggplot2::labs(x     = "",
                      y     = "Density",
                      title = paste0("C[",i,",",j,"]")) +
        ggplot2::theme(legend.position = "bottom",
                       legend.title    = ggplot2::element_blank(),
                       ...
                       )

      plot_cm_list[[plot_cm_indx]] <- p

      # Increment the index of stored graph:
      plot_cm_indx <- plot_cm_indx + 1

    }# End for
  }# End for


  plots_no_legend <- lapply(plot_cm_list[1:(age_grps^2)],
                            function(x) x + ggplot2::theme(legend.position="none"))

  gridExtra::grid.arrange( gridExtra::arrangeGrob(grobs = plots_no_legend, nrow = age_grps) )

}
