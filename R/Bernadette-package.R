#' Bayesian inference and model selection for stochastic epidemics
#'
#' \code{Bernadette} provides Bayesian analysis for stochastic extensions of dynamic non-linear systems using advanced computational algorithms.
#'
#' @docType package
#' @name Bernadette-package
#' @aliases Bernadette
#' @useDynLib Bernadette, .registration=TRUE
#' @rawNamespace import(stats, except = c(recode, lag, filter))
#' @import dplyr
#' @import ggplot2
#' @import lubridate
#' @import methods
#' @importFrom readr read_csv cols
#' @import RcppParallel
#' @rawNamespace import(Rcpp, except = c(LdFlags))
#' @import rstantools
#' @importFrom rstan sampling
#' @importFrom scales percent
#' @import scoringRules
#' @import tibble
#' @import tidyr
#' @importFrom utils unstack data
#'
#' @references Stan Development Team (2020). RStan: the R interface to Stan. R
#' package version 2.21.3. https://mc-stan.org
NULL
