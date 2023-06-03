#' Bayesian diffusion-driven multi-type epidemic models via Stan
#'
#' A Bayesian evidence synthesis approach to model the age-specific transmission
#' dynamics of COVID-19 based on daily age-stratified mortality counts. The temporal
#' evolution of transmission rates in populations containing multiple types of individual
#' is reconstructed via independent diffusion processes assigned to the key epidemiological
#' parameters. A suitably tailored Susceptible-Exposed-Infected-Removed (SEIR) compartmental
#' model is used to capture the latent counts of infections and to account for fluctuations
#' in transmission influenced by phenomena like public health interventions and changes in human behaviour.
#'
#' @param y_data data.frame;
#' age-specific mortality counts in time. See \code{data(age_specific_mortality_counts)}.
#'
#' @param contact_matrix matrix;
#' a squared matrix representing the the number of contacts between age groups.
#'
#' @param age_distribution_population data.frame;
#' the age distribution of a given population. See \code{aggregate_age_distribution}.
#'
#' @param itd_distr vector;
#' Infection-to-death distribution. A vector of length \emph{ts_length}.
#'
#' @param age_specific_ifr data.frame;
#' time-varying age-specific infection-fatality ratio. See \code{aggregate_ifr_react}.
#'
#' @param incubation_period integer;
#' length of incubation period in days. Must be >=1.
#'
#' @param infectious_period integer;
#' length of infectious period in days. Must be >=1.
#'
#' @param likelihood_variance_type integer;
#' If \eqn{0}, the variance of the over-dispersed count model is a quadratic function of the mean;
#' if \eqn{1}, the variance of the over-dispersed count model is a linear function of the mean.
#'
#' @param prior_scale_x0 double;
#' scale parameter of a Normal prior distribution assigned to the age-specific log(transmissibility) at time \eqn{t = 0}.
#'
#' @param prior_scale_x1 double;
#' scale parameter of a Normal prior distribution assigned to the age-specific log(transmissibility) at time \eqn{t = 1}.
#'
#' @param prior_scale_contactmatrix double;
#' defaults to 0.05. A positive number that scales the informative Normal prior distribution assigned to the random contact matrix.
#'
#' @param pi_perc numeric;
#' between 0 and 1. It represents the proportion of Exposed individuals in each age group of a given population at time \eqn{t = 0}.
#' while the rest \eqn{100*(1-pi_perc)} remain Susceptible.
#'
#' @param prior_volatility
#' Prior distribution for the volatility parameters of the age-specific diffusion processes.
#' \code{prior_volatility} can be a call to \code{exponential} to use an exponential distribution, \code{gamma}
#' to use a Gamma distribution or one of \code{normal}, \code{student_t} or \code{cauchy} to use a half-normal,
#' half-t, or half-Cauchy prior. See \code{priors} for details on these functions.
#'
#' @param prior_nb_dispersion
#' Prior distribution for the dispersion parameter \code{phi} of the over-dispersed count model.
#' Same options as for \code{prior_volatility}.
#'
#' @param algorithm_inference
#' One of the sampling algorithms that are implemented in Stan. See \code{\link[rstan]{stan}}.
#'
#' @param nBurn integer;
#' number of burn-in iterations at the beginning of an MCMC run. See \code{\link[rstan]{sampling}}.
#'
#' @param nPost integer;
#' number of MCMC iterations after burn-in. See \code{\link[rstan]{sampling}}.
#'
#' @param nThin integer;
#' a positive integer specifying the period for saving samples. The default is 1, which is usually the recommended value.
#' See \code{\link[rstan]{sampling}}.
#'
#' @param adapt_delta double;
#' between 0 and 1, defaults to 0.8. See \code{\link[rstan]{stan}}.
#'
#' @param max_treedepth integer;
#' defaults to 14. See \code{\link[rstan]{stan}}.
#'
#' @param seed integer;
#' seed for the random number generator. See \code{set.seed}.
#'
#' @param ... Additional arguments, to be passed to lower-level functions.
#'
#' @details
#' The \code{stan_igbm} function performs full Bayesian estimation (if
#' \code{algorithm_inference} is \code{"sampling"}) via MCMC. The Bayesian model adds
#' priors (i) on the diffusion processes used to express the time-varying transmissibility
#' of the virus, the probability that a contact between an infectious person in age
#' group alpha and a susceptible person in age group alpha leads to
#' transmission at time \eqn{t} and (ii) on a random contact matrix which represents
#' the average number of contacts between individuals of age group alpha and
#' age group alpha' The \code{stan_igbm} function calls the workhorse
#' \code{stan_igbm.fit} function.
#'
#' @return An object of class \emph{stanigbm} representing the fitted results. Slot mode for this object indicates if the sampling is done or not.
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
#'                       prior_scale_x0              = 0.5,
#'                       prior_scale_x1              = 0.5,
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
#' summary(igbm_fit)
#'}
#' @export
#'
stan_igbm <-
  function(y_data,
           contact_matrix,
           age_distribution_population,
           age_specific_ifr,
           itd_distr,
           incubation_period         = 3,
           infectious_period         = 4,
           likelihood_variance_type  = c("quadratic", "linear"),
           prior_scale_x0            = 1,
           prior_scale_x1            = 1,
           prior_scale_contactmatrix = 0.05,
           pi_perc             = 0.1,   # Assume that 10% of each age group are Exposed, rest 90% are Susceptible
           prior_volatility    = normal(location = 0, scale = 2.5),
           prior_nb_dispersion = gamma(shape = 2, rate = 1),
           algorithm_inference = c("sampling", "optimizing", "meanfield", "fullrank"),
           nBurn               = 500,
           nPost               = 500,
           nThin               = 1,
           adapt_delta         = 0.8,
           max_treedepth       = 14,
           seed                = 1,
           ...
           ) {

    if( is.null(y_data) | is.null(contact_matrix) | is.null(age_distribution_population) | is.null(age_specific_ifr) )
      stop("Please provide the data sources that are missing from ('y_data', 'contact_matrix', 'age_distribution_population', 'age_specific_ifr').")

    if( nrow(age_distribution_population) != ncol(contact_matrix) )
     stop("Incorrect dimensions - The age distribution of the population and the contact matrix must refer to the same number of age groups.")

    if( nrow(age_specific_ifr) != nrow(y_data) )
     stop("The number of rows of 'age_specific_ifr' must be equal to the number of rows of 'y_data'.")

    if( !identical(colnames(y_data[,-c(1:5)]), age_distribution_population$AgeGrp))
      stop("The mortality counts dataset 'y_data' and the age distribution of the population 'age_distribution_population' must refer to the same age group labels.")

    if( !identical(colnames(y_data[,-c(1:5)]), colnames(age_specific_ifr[,-1]) ) )
      stop("The mortality counts dataset 'y_data' and the age-specific IFR dataset 'age_specific_ifr' must refer to the same age group labels.")

    if( !identical(y_data$Date, age_specific_ifr$Date ) )
      stop("The ordering of the dates between the dataset 'y_data' and the dataset 'age_specific_ifr' must be identical.")

    if( length(itd_distr) != nrow(y_data) )
      stop("The length of 'itd_distr' must be equal to the number of rows of 'y_data'.")

    if( incubation_period  == 0)
      stop("'incubation_period' must be set to a positive integer number.")

    if( infectious_period  == 0)
      stop("'infectious_period' must be set to a positive integer number.")

    if( likelihood_variance_type %nin% c("quadratic", "linear") )
      stop("'likelihood_variance_type' must be set to one of 'quadratic' or 'linear'.")

    if( algorithm_inference %nin% c("sampling", "optimizing", "meanfield", "fullrank") )
      stop("'algorithm_inference' must be set to one of 'sampling', 'optimizing', 'meanfield', 'fullrank'.")

    if( pi_perc > 1 )
      stop("'pi_perc' must be between 0 and 1.")

    pi_prior_params          <- lapply(pi_perc, function(x) estBetaParams(x, (0.05*x)) )
    algorithm_inference      <- match.arg(algorithm_inference)
    likelihood_variance_type <- match.arg(likelihood_variance_type)

    if( likelihood_variance_type == "quadratic") l_variance_type <- 0 else if(likelihood_variance_type == "linear") l_variance_type <- 1

    standata_preproc <-
      nlist(Dates              = y_data$Date,
            A                  = nrow(age_distribution_population),
            n_obs              = nrow(y_data),
            y_data             = y_data[,-c(1:5)],
            n_pop              = sum(age_distribution_population$PopTotal),
            age_dist           = age_distribution_population$PopTotal/sum(age_distribution_population$PopTotal),
            pop_diag           = 1/(age_distribution_population$PopTotal),
            n_difeq            = length(c("S", "E", "E", "I", "I", "C")),
            L_cm               = t( base::chol( base::diag(age_distribution_population$PopTotal) %*% as.matrix(contact_matrix) ) ),
            age_specific_ifr   = age_specific_ifr[,-1], # Remove the Date column
            I_D                = itd_distr,
            t0                 = 0,
            ts                 = y_data$Index,
            left_t             = y_data$Index,
            right_t            = y_data$Right,
            E_deathsByAge_day1 = unlist(y_data[1,-c(1:5)]) + 0.001,
            incubation_period  = incubation_period,
            infectious_period  = infectious_period,
            prior_scale_x0     = prior_scale_x0,
            prior_scale_x1     = prior_scale_x1,
            prior_dist_pi      = data.frame(do.call(rbind, pi_prior_params)),
            likelihood_variance_type  = l_variance_type,
            prior_scale_contactmatrix = prior_scale_contactmatrix
            )

    stanfit <-
            stan_igbm.fit(standata_preprocessed = standata_preproc,
                          prior_volatility      = prior_volatility,
                          prior_nb_dispersion   = prior_nb_dispersion,
                          algorithm             = algorithm_inference,
                          nBurn                 = nBurn,
                          nPost                 = nPost,
                          nThin                 = nThin,
                          adapt_delta           = adapt_delta,
                          max_treedepth         = max_treedepth,
                          seed                  = seed,
                          ...)
  }
