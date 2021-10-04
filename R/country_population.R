#' Country-specific total population
#'
#' Function to extract the total population of a country for a given year, based on
#' the United Nations 2019 Revision of World Population Prospects.
#'
#' @param country character; country identifier, following the \href{https://www.un.org/en/about-us/member-states}{List of United Nations Member States}. See \link[Bernadette]{countries_un}.
#'
#' @param year numeric; calendar year
#'
#' @return An object of type "numeric", containing the population figure for a given country and calendar year.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' @examples
#'
#' \dontrun{
#'country_pop <- country_population(country = "Greece",
#'                                  year    = 2020)
#'}
#'
#' @export
#'
country_population <- function(country,
                               year = NULL
){

  if(country %in% countries_un() == FALSE) stop("The user-defined country name is not available. Please check countries_un().")

  tmp_env <- new.env()

  utils::data(demographics_un, envir = tmp_env)

  dem_table <- tmp_env$demographics_un

  unique_years <- unique(dem_table$Time)
  stopifnot(year %in% unique_years)

  filter <- dem_table$Location == country & dem_table$Time == year

  pop <- as.numeric( sum( unique(dem_table[filter, "PopTotal"]) ) )

  if (pop < 0) stop("The population is negative.")

  return(pop)

}
