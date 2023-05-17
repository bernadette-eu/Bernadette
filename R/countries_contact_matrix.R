#' Names of countries for which a contact matrix is available
#'
#' Function to extract the names of the countries whose projected contact matrix is available.
#'
#' @return A character vector of length 177 with the IDs of each of the 177 geographical regions.
#'
#' @references
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2017). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
#'
#' @examples
#' country_contact_matrices()
#'
#' @export
#'
country_contact_matrices <- function() {
  tmp_env <- new.env()

  utils::data(contact_matrices, envir = tmp_env)

  out              <- tmp_env$contact_matrices
  country_initials <- names(out)

  return (country_initials)
}
