#' Plot the posterior contact matrix
#'
#' @param object An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{theme}}.
#'
#' @return A \code{grid.arrange} object which can be further customised using the \pkg{gridExtra} package.
#'
#' @references
#' Bouranis, L., Demiris, N. Kalogeropoulos, K. and Ntzoufras, I. (2022). Bayesian analysis of diffusion-driven multi-type epidemic models with application to COVID-19. arXiv: \url{https://arxiv.org/abs/2211.15229}
#'
#' @examples
#' \dontrun{
#' if (.Platform$OS.type != "windows" || .Platform$r_arch != "i386") {
#' # Age-specific mortality/incidence count time series:
#' data(age_specific_mortality_counts)
#' data(age_specific_infection_counts)
#'
#' # Import the age distribution for a country in a given year:
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
#' # Import the projected contact matrix for a country (i.e. Greece):
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
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       itd_distr                   = ditd,
#'                       likelihood_variance_type    = "quadratic",
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = gamma(shape = 2, rate = 1),
#'                       algorithm_inference         = "sampling")
#'
#' # Visualise the posterior distribution of the random contact matrix:
#' plot_posterior_cm(igbm_fit)
#' }
#'}
#' @export
plot_posterior_cm <- function(object, ...){

  if(class(object)[1] != "stanigbm") stop("Provide an object of class 'stanigbm' using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object$stanfit)
  cov_data        <- object$standata

  if(ncol(posterior_draws$cm_sample) != cov_data$A) stop( paste0("The number of rows in the age distribution table must be equal to ", cov_data$A) )

  niters       <- nrow(posterior_draws[["cm_sample"]])
  plot_cm_list <- list()
  plot_cm_indx <- 1

  for (i in 1:cov_data$A){
    for (j in 1:cov_data$A){

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


  plots_no_legend <- lapply(plot_cm_list[1:(cov_data$A^2)],
                            function(x) x + ggplot2::theme(legend.position="none"))

  gridExtra::grid.arrange( gridExtra::arrangeGrob(grobs = plots_no_legend, nrow = cov_data$A) )

}
