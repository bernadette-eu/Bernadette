#' Country-specific age distribution
#'
#' Function to extract the age distribution of a country for a given year, broken
#' down by 5-year age bands and gender, following the United Nations 2019 Revision of
#' World Population Prospects.
#'
#' @param country character; country identifier, following the \href{https://www.un.org/en/about-us/member-states}{List of United Nations Member States}. See \link[Bernadette]{countries_un}.
#'
#' @param year numeric; calendar year
#'
#' @return A data frame that contains the age distribution.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' @examples
#'
#' \dontrun{
#'age_distr <- age_distribution(country = "Greece",
#'                              year    = 2020)
#'}
#'
#' @export
age_distribution <- function(country,
                             year
){

  if(country %in% countries_un() == FALSE) stop("The user-defined country name is not available. Please check countries_un().")

  tmp_env <- new.env()

  utils::data(demographics_un, envir = tmp_env)

  dem_table <- tmp_env$demographics_un

  filter    <- dem_table$Location == country & dem_table$Time == year
  dem_table <- unique( dem_table[filter, ] )

  dem_table_pre70  <- dem_table[dem_table$AgeGrpStart < 75,]
  dem_table_75plus <- dem_table[dem_table$AgeGrpStart >= 75,]

  subtot <- t( data.frame(colSums(dem_table_75plus[,c("PopMale", "PopFemale", "PopTotal")]) ) )
  rownames(subtot) <- NULL

  dem_table_75plus <- cbind(dem_table_75plus[1,c("Location", "Time", "AgeGrp", "AgeGrpStart")], subtot)

  dem_table_75plus$AgeGrp <- "75+"

  out <- rbind(dem_table_pre70, dem_table_75plus)
  out <- as.data.frame(out)

  return(out)

}# End function
