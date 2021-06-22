#' Country-specific total population
#'
#' Function to extract the total population of a country for a given year, based on
#' the United Nations 2019 Revision of World Population Prospects.
#'
#' @param country character; country identifier, following the \href{https://www.un.org/en/about-us/member-states}{List of United Nations Member States}.
#'
#' @param year numeric; calendar year
#'
#' @return An object of type "numeric", containing the population figure for a given country and calendar year.
#'
#' @examples
#'
#' \dontrun{
#'country_population <- extract_country_pop(country = "Greece",
#'                                           year    = 2020)
#'}
#'
#' @export
#'
country_population <- function(country,
                               year = NULL
){

  if (!is.character(country)) stop("Parameter 'country' must be character")

  if (is.null(country)) stop("Parameter 'year' must be numeric")

  url <- paste0("https://population.un.org/wpp/Download/Files/",
                "1_Indicators%20(Standard)/CSV_FILES/",
                "WPP2019_TotalPopulationBySex.csv")
  table <- readr::read_csv(url, col_types = readr::cols())

  table <- table[table$Location == country & table$Time == year, "PopTotal"][1,]*1000

  pop <- as.numeric(table)

  if (pop < 0) stop("The population is negative.")

  return(pop)

}
