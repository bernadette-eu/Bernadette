#' Names of countries with an available age distribution
#'
#' Function to extract the names of the countries whose discrete age distribution is
#' available by the United Nations.
#'
#' @return A character vector that contains the full names of 201 countries/areas.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2017). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
#'
#' @examples
#' countries_un()
#'
#' @export
#'
countries_un <- function() {
  data_path <- paste0("https://github.com//kieshaprem//synthetic-contact-matrices//",
                      "raw//master//generate_synthetic_matrices//input//pop//",
                      "poptotal",
                      ".rdata" )
  load(base::url(data_path))

  country_names <- as.vector( unique(poptotal$countryname) )

  return(country_names)
}
