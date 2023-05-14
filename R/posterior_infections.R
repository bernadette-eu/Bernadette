#' Summarize the posterior distribution of the infection counts
#'
#' @param object An object of class \code{stanigbm}. See \code{\link[Bernadette]{stan_igbm}}.
#'
#' @return A list of two dataframes which can be visualised using \code{\link[Bernadette]{plot_posterior_infections}}.
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
#' # Posterior sampling:
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       likelihood_variance_type    = 0,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = gamma(shape = 2, rate = 1),
#'                       algorithm_inference         = "sampling")
#'
#' post_inf_summary <- plot_posterior_infections(igbm_fit)
#'
#' # Visualise the posterior distribution of the infection counts:
#' plot_posterior_infections(post_inf_summary, type = "age-specific")
#' plot_posterior_infections(post_inf_summary, type = "age-aggregated")
#' }
#'}
#' @export
posterior_infections <- function(object){

  if(class(object)[1] != "stanigbm") stop("Provide an object of class 'stanigbm' using rstan::sampling() or rstan::vb()")

  posterior_draws <- rstan::extract(object$stanfit)
  cov_data        <- object$standata
  dates           <- cov_data$Date

  #---- Age-specific:
  output_age_cols     <- c("Date", "Group", "median", "low", "high", "low25", "high75")
  output_age           <- data.frame(matrix(ncol = length(output_age_cols), nrow = 0))
  colnames(output_age) <- output_age_cols

  for (i in 1:cov_data$A){

    fit_age               <- posterior_draws$E_casesByAge[,,i]
    dt_infections_age_grp <- data.frame(Date  = dates,
                                        Group = rep( colnames(cov_data$y_data)[i], length(dates) ) )

    dt_infections_age_grp        <- data.frame(Date = dates)
    dt_infections_age_grp$median <- apply(fit_age, 2, median)
    dt_infections_age_grp$low    <- apply(fit_age, 2, quantile, probs = c(0.025))
    dt_infections_age_grp$high   <- apply(fit_age, 2, quantile, probs = c(0.975))
    dt_infections_age_grp$low25  <- apply(fit_age, 2, quantile, probs = c(0.25))
    dt_infections_age_grp$high75 <- apply(fit_age, 2, quantile, probs = c(0.75))

    output_age <- rbind(output_age, dt_infections_age_grp)
  }

  #---- Aggregated:
  fit_aggregated           <- posterior_draws$E_cases
  output_aggregated        <- data.frame(Date = dates)
  output_aggregated$median <- apply(fit_aggregated, 2, median)
  output_aggregated$low    <- apply(fit_aggregated, 2, quantile, probs = c(0.025))
  output_aggregated$high   <- apply(fit_aggregated, 2, quantile, probs = c(0.975))
  output_aggregated$low25  <- apply(fit_aggregated, 2, quantile, probs = c(0.25))
  output_aggregated$high75 <- apply(fit_aggregated, 2, quantile, probs = c(0.75))

  output <- list(Age_specific = output_age,
                 Aggregated   = output_aggregated)

  return(output)
}

#' Plot the posterior distribution of the infection counts
#'
#' @param object
#' A dataframe from \code{\link[Bernadette]{posterior_infections}}.
#'
#' @param type character;
#' Plot the output for the 'age-specific' infection counts or the 'aggregated' infections.
#'
#' @param xlab character;
#' title of x-axis.
#'
#' @param ylab character;
#' title of y-axis.
#'
#' @param ... Optional arguments passed to \code{\link[ggplot2]{facet_wrap}}, \code{\link[ggplot2]{scale_x_date}} and \code{\link[ggplot2]{theme}}.
#'
#' @return A \code{ggplot} object which can be further customised using the \pkg{ggplot2} package.
#'
#' @seealso \code{\link{posterior_infections}}.
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
#' # Posterior sampling:
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       likelihood_variance_type    = 0,
#'                       prior_volatility            = normal(location = 0, scale = 1),
#'                       prior_nb_dispersion         = gamma(shape = 2, rate = 1),
#'                       algorithm_inference         = "sampling")
#'
#' post_inf_summary <- plot_posterior_infections(igbm_fit)
#'
#' # Visualise the posterior distribution of the infection counts:
#' plot_posterior_infections(post_inf_summary, type = "age-specific")
#' plot_posterior_infections(post_inf_summary, type = "age-aggregated")
#' }
#'}
#' @export
plot_posterior_infections <- function(object,
                                      type = c("age-specific", "aggregated"),
                                      xlab = NULL,
                                      ylab = NULL,
                                      ...){

  aggr_type <- match.arg(type)

  if (is.null(xlab)) xlab <- "Epidemiological Date"
  if (is.null(ylab)) ylab <- "New daily infection counts"

  if (aggr_type %nin% type){

    stop("Please select a type of aggregation from ('age-specific', 'aggregated').")

  } else if (aggr_type == "age-specific"){

    ret <-
      ggplot2::ggplot(object$Age_specific) +
      ggplot2::facet_wrap(. ~ Group, ...) +
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
                     legend.title    = ggplot2::element_blank(),
                     ...)

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
                       legend.title    = ggplot2::element_blank(),
                       ...)
  }

  ret
}
