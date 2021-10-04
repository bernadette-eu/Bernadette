#' Names of countries with an available age distribution
#'
#' Function to extract the names of the countries whose discrete age distribution is
#' available by the United Nations.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' @export
#'
countries_un <- function() {
  tmp_env <- new.env()

  utils::data(demographics_un, envir = tmp_env)

  country_names <- as.vector( unique(tmp_env$demographics_un$Location) )

  return(country_names)
}
