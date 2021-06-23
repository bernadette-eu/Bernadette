#' Country-specific population by gender and age group, with 5-year bands.
#'
#' Function to extract the population of a country for a given year, broken
#' down by gender and 5-year age bands, following the United Nations 2019 Revision
#' of World Population Prospects.
#'
#' @param country character; country identifier, following the \href{https://www.un.org/en/about-us/member-states}{List of United Nations Member States}.
#'
#' @param year numeric; calendar year
#'
#' @param stratify_gender logical; TRUE/FALSE: aggregate the population by gender only.
#'
#' @return A data frame that contains the portion of the population per grouping.
#'
#' @examples
#'
#' \dontrun{
#'check_age <- extract_pop_age_gender(country         = "Greece",
#'                                    year            = 2020,
#'                                    stratify_gender = FALSE)
#'}
#'
#' @export
#'
extract_pop_age_gender <- function(country,
                                   year,
                                   stratify_gender = FALSE
){

  data_path <- paste0("https://population.un.org/wpp/Download/Files/",
                      "1_Indicators%20(Standard)/CSV_FILES/",
                      "WPP2019_PopulationByAgeSex_OtherVariants",
                      ".csv" )

  dt_pop    <- readr::read_csv(data_path, col_types = readr::cols() )

  keep_cols <- c("Location",
                 "Time",
                 "AgeGrp",
                 "AgeGrpStart",
                 "PopMale",
                 "PopFemale",
                 "PopTotal" )

  data_filter <- dt_pop$Location == country & dt_pop$Time == year
  dt_pop      <- unique( dt_pop[data_filter, keep_cols] )

  pop_cols    <- c("PopMale", "PopFemale", "PopTotal")

  dt_pop[,pop_cols] <- dt_pop[,pop_cols]*1000

  if (stratify_gender == TRUE){

    subtot <- t( data.frame(colSums(dt_pop[,c("PopMale", "PopFemale", "PopTotal")]) ) )
    rownames(subtot) <- NULL

    dt_pop <- cbind(dt_pop[1,c("Location", "Time")], subtot)

  }# End if

  return(dt_pop)

}# End function
