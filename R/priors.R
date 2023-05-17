#' Prior distributions and options
#'
#' @name priors
#'
#' @description The functions described on this page are used to specify the
#'   prior-related arguments of the modeling functions in the
#'   \pkg{Bernadette} package.
#'
#'   The default priors used in the \pkg{Bernadette} modeling functions
#'   are intended to be \emph{weakly informative}. For many applications the
#'   defaults will perform well, but prudent use of more informative priors is
#'   encouraged. Uniform prior distributions are possible (e.g. by setting
#'   \code{\link{stan_igbm}}'s \code{prior} argument to \code{NULL}) but, unless
#'   the data is very strong, they are not recommended and are \emph{not}
#'   non-informative, giving the same probability mass to implausible values as
#'   plausible ones.
#'
#' @param location
#' Prior location. In most cases, this is the prior mean, but
#'   for \code{cauchy} (which is equivalent to \code{student_t} with
#'   \code{df=1}), the mean does not exist and \code{location} is the prior
#'   median. The default value is \eqn{0}.
#'
#' @param scale
#' Prior scale. The default depends on the family (see \strong{Details}).
#'
#' @param df
#' Degrees of freedom.
#'
#' @param shape
#' Prior shape for the Gamma distribution. Defaults to \code{2}.
#'
#' @param rate
#' Prior rate for the Gamma or the Exponential distribution. Defaults to \code{1}.
#'
#' @details The details depend on the family of the prior being used:
#' \subsection{Student t family}{
#'   Family members:
#'   \itemize{
#'   \item \code{normal(location, scale)}
#'   \item \code{student_t(df, location, scale)}
#'   \item \code{cauchy(location, scale)}
#'   }
#'
#'   As the degrees of freedom approaches infinity, the Student t distribution
#'   approaches the normal distribution and if the degrees of freedom are one,
#'   then the Student t distribution is the Cauchy distribution.
#'   If \code{scale} is not specified it will default to \eqn{2.5}.
#' }
#'
#' @return A named list to be used internally by the \pkg{Bernadette} model
#'   fitting functions.
#'
#' @seealso The vignette for the \pkg{Bernadette} package discusses
#'   the use of some of the supported prior distributions.
#'
#' @examples
#' \donttest{
#' # Age-specific mortality/incidence count time series:
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
#' # Can assign priors to names:
#' N05      <- normal(0, 5)
#' Gamma22  <- gamma(2,2)
#' igbm_fit <- stan_igbm(y_data                      = age_specific_mortality_counts,
#'                       contact_matrix              = aggr_cm,
#'                       age_distribution_population = aggr_age,
#'                       age_specific_ifr            = aggr_age_ifr[[3]],
#'                       itd_distr                   = ditd,
#'                       likelihood_variance_type    = "quadratic",
#'                       prior_volatility            = N05,
#'                       prior_nb_dispersion         = Gamma22,
#'                       algorithm_inference         = "optimizing")
#' }
NULL

#' @rdname priors
#' @export
normal <- function(location = 0, scale = NULL) {
  validate_parameter_value(scale)
  nlist(dist = "normal", df = NA, location, scale, shape = NA, rate = NA)
}

#' @rdname priors
#' @export
student_t <- function(df = 1, location = 0, scale = NULL) {
  validate_parameter_value(scale)
  validate_parameter_value(df)
  nlist(dist = "t", df, location, scale, shape = NA, rate = NA)
}

#' @rdname priors
#' @export
cauchy <- function(location = 0, scale = NULL) {
  student_t(df = 1, location = location, scale = scale)
}

#' @rdname priors
#' @export
#' @param shape Prior shape for the gamma distribution. Defaults to \code{2}.
#' @param rate Prior rate for the gamma distribution. Defaults to \code{1}.
gamma <- function(shape = 2, rate = 1) {
  stopifnot(length(shape) == 1)
  stopifnot(length(rate)  == 1)
  validate_parameter_value(shape)
  validate_parameter_value(rate)
  nlist(dist = "gamma", df = NA, location = NA, scale = NA, shape, rate)
}


#' @rdname priors
#' @export
#' @param rate Prior rate for the exponential distribution. Defaults to
#'   \code{1}. For the exponential distribution, the rate parameter is the
#'   \emph{reciprocal} of the mean.
#'
exponential <- function(rate = 1) {
  stopifnot(length(rate) == 1)
  validate_parameter_value(rate)

  nlist(dist = "exponential", df = NA, location = NA, scale = NA, shape = NA, rate)
}

# internal ----------------------------------------------------------------

# Check for positive scale or df parameter (NULL OK)
#
# @param x The value to check.
# @return Either an error is thrown or \code{TRUE} is returned invisibly.
validate_parameter_value <- function(x) {
  nm <- deparse(substitute(x))
  if (!is.null(x)) {
    if (!is.numeric(x))
      stop(nm, " should be NULL or numeric", call. = FALSE)
    if (any(x <= 0))
      stop(nm, " should be positive", call. = FALSE)
  }
  invisible(TRUE)
}

# Deal with priors
#
# @param prior A list
# @param default_mean Default value to use for the mean if not specified by user
# @param default_scale Default value to use to scale if not specified by user
# @param default_df Default value to use for the degrees of freedom if not specified by user
# @param default_shape Default value to use for the shape if not specified by user
# @param default_rate Default value to use for the rate if not specified by user
# @param ok_dists A list of admissible distributions.
handle_prior <- function(prior,
                         default_mean = 0,
                         default_scale = 2.5,
                         default_df = 1,
                         default_shape = 2,
                         default_rate = 1,
                         ok_dists = nlist("normal",
                                          student_t = "t",
                                          "cauchy",
                                          "gamma",
                                          "exponential")) {

  if (!length(prior))
    return(list(prior_dist      = 1L,
                prior_mean      = default_mean,
                prior_scale     = default_scale,
                prior_df        = default_df,
                prior_shape     = default_shape,
                prior_rate      = default_rate,
                prior_dist_name = "normal"))

  if (!is.list(prior)) stop(base::sQuote(deparse(substitute(prior))), " should be a named list")

  prior_dist_name <- prior$dist

  if (!prior_dist_name %in% unlist(ok_dists)) {

    stop("The prior distribution should be one of ", paste(names(ok_dists), collapse = ", "))

  } else if (prior_dist_name %in%
             c("normal",
               "t",
               "cauchy",
               "gamma",
               "exponential")) {

    if (prior_dist_name == "normal") { prior_dist <- 1L
    } else if (prior_dist_name == "cauchy") { prior_dist <- 2L
    } else if (prior_dist_name == "t") { prior_dist <- 3L
    } else if (prior_dist_name == "gamma") { prior_dist <- 4L
    } else if (prior_dist_name == "exponential"){ prior_dist <- 5L }

    prior_mean      <- prior$location
    prior_scale     <- prior$scale
    prior_df        <- prior$df
    prior_shape     <- prior$shape
    prior_rate      <- prior$rate

    prior_mean[is.na(prior_mean)]   <- default_mean
    prior_scale[is.na(prior_scale)] <- default_scale
    prior_df[is.na(prior_df)]       <- default_df
    prior_shape[is.na(prior_shape)] <- default_shape
    prior_rate[is.na(prior_rate)]   <- default_rate

  }# End if

  nlist(prior_dist,
        prior_mean,
        prior_scale,
        prior_df,
        prior_shape,
        prior_rate,
        prior_dist_name)
}
