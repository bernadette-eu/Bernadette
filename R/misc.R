# Set arguments for sampling
#
# Prepare a list of arguments to use with \code{rstan::sampling} via
# \code{do.call}.
#
# @param object The stanfit object to use for sampling.
#
# @param user_dots The contents of \code{...} from the user's call to
#   the \code{stan_*} modeling function.
#
# @param user_adapt_delta numeric; The value for \code{adapt_delta} specified by the user.
#
# @param user_max_treedepth numeric; The value for \code{max_treedepth} specified by the user.
#
# @param ... Other arguments to \code{\link[rstan]{sampling}} not coming from
#   \code{user_dots} (e.g. \code{data}, \code{pars}, \code{init}, etc.).
#
# @return A list of arguments to use for the \code{args} argument for
#   \code{do.call(sampling, args)}.
set_sampling_args <- function(object,
                              user_dots          = list(),
                              user_adapt_delta   = NULL,
                              user_max_treedepth = NULL,
                              ...) {

  args <- list(object = object, ...)
  unms <- names(user_dots)

  for (j in seq_along(user_dots)) args[[unms[j]]] <- user_dots[[j]]

  defaults <- default_stan_control(adapt_delta   = user_adapt_delta,
                                   max_treedepth = user_max_treedepth)

  if (!"control" %in% unms) {

    # no user-specified 'control' argument
    args$control <- defaults

  } else {

    # user specifies a 'control' argument
    if (!is.null(user_adapt_delta)) {
      # if user specified adapt_delta argument to stan_* then
      # set control$adapt_delta to user-specified value
      args$control$adapt_delta <- user_adapt_delta
    } else {
      # use default adapt_delta for the user's chosen prior
      args$control$adapt_delta <- defaults$adapt_delta
    }

    if (!is.null(user_max_treedepth)) {
      # if user specified max_treedepth argument to stan_* then
      # set control$max_treedepth to user-specified value
      args$control$max_treedepth <- user_max_treedepth
    } else {
      # use default adapt_delta for the user's chosen prior
      args$control$max_treedepth <- defaults$max_treedepth
    }

  }
  args$save_warmup <- FALSE

  return(args)
}

# Default control arguments for sampling
#
# Called by set_sampling_args to set the default 'control' argument for
# \code{rstan::sampling} if none specified by user.
#
# @param adapt_delta numeric; User's \code{adapt_delta} argument.
# @param max_treedepth numeric; Default for \code{max_treedepth}.
# @return A list with \code{adapt_delta} and \code{max_treedepth}.
default_stan_control <- function(adapt_delta   = NULL,
                                 max_treedepth = NULL) {

  if (is.null(adapt_delta))   adapt_delta   <- 0.80
  if (is.null(max_treedepth)) max_treedepth <- 15L

  nlist(adapt_delta, max_treedepth)
}


# Test if an object is a stanigbm object
#
# @param x The object to test.
is.stanigbm <- function(x) inherits(x, "stanigbm")

# Throw error if object isn't a stanreg object
#
# @param x The object to test.
validate_stanigbm_object <- function(x, call. = FALSE) {
  if (!is.stanigbm(x))
    stop("Object is not a stanigbm object.", call. = call.)
}

# Check that a stanfit object (or list returned by rstan::optimizing) is valid
check_stanfit <- function(x) {
  if (is.list(x)) {
    if (!all(c("par", "value") %in% names(x)))
      stop("Invalid object produced please report bug")
  }
  else {
    stopifnot(is(x, "stanfit"))
    if (x@mode != 0)
      stop("Invalid stanfit object produced please report bug")
  }
  return(TRUE)
}

# Convert mean and variance to alpha and beta parameters for a Beta(alpha, beta) distribution
#
# The calculations will only work (alpha, beta > 0) if the variance is less than mean*(1-mean).
#
# @param mu numeric; Mean of Beta distribution.
# @param variance numeric; Variance of Beta distribution.
estBetaParams <- function(mu, var) {

  if ( var >= mu*(1-mu) ) stop("Ensure that var < mu*(1-mu).")

  alpha <- ((1 - mu) / var - 1 / mu) * mu ^ 2
  beta  <- alpha * (1 / mu - 1)

  return(params = c(alpha = alpha, beta = beta))
}# End function

# Create a named list using specified names or, if names are omitted, using the
# names of the objects in the list
#
# @param ... Objects to include in the list.
# @return A named list.
nlist <- function(...) {
  m        <- match.call()
  out      <- list(...)
  no_names <- is.null(names(out))
  has_name <- if (no_names) FALSE else nzchar(names(out))

  if (all(has_name))
    return(out)
  nms <- as.character(m)[-1L]
  if (no_names) {
    names(out) <- nms
  } else {
    names(out)[!has_name] <- nms[!has_name]
  }

  return(out)
}

# Calculate the spectral radius of a matrix
#
# @param x a numeric or complex matrix whose spectral decomposition is to be computed.
#    Logical matrices are coerced to numeric.
eigen_mat  <- function(x) base::max( base::Re( base::eigen(x)$values ) )

#---- Helpers:
`%nin%` <- Negate(`%in%`)
