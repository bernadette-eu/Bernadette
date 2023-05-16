#' Bayesian inference and model selection for stochastic epidemics
#'
#' \code{Bernadette} provides Bayesian analysis for stochastic extensions of dynamic non-linear systems using advanced computational algorithms.
#'
#' @docType package
#' @name Bernadette-package
#' @aliases Bernadette
#' @useDynLib Bernadette, .registration=TRUE
#' @import ggplot2
#' @importFrom grid unit.c
#' @importFrom gridExtra grid.arrange arrangeGrob
#' @importFrom magrittr `%>%`
#' @import methods
#' @rawNamespace import(Rcpp, except = c(LdFlags,.DollarNames,prompt))
#' @import RcppParallel
#' @importFrom readr read_csv cols
#' @import rstantools
#' @importFrom rstan optimizing sampling vb extract
#' @importFrom scales percent pretty_breaks
#' @rawNamespace import(stats, except = c(recode, lag, filter))
#' @import utils
#'
#' @references
#' Bouranis, L., Demiris, N. Kalogeropoulos, K. and Ntzoufras, I. (2022). Bayesian analysis of diffusion-driven multi-type epidemic models with application to COVID-19. arXiv: \url{https://arxiv.org/abs/2211.15229}
#'
#' Stan Development Team (2020). RStan: the R interface to Stan. R package version 2.21.3. \url{https://mc-stan.org}
NULL
