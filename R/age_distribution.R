#' Country-specific age distribution
#'
#' Function to extract the age distribution of a country for a given year, broken
#' down by 5-year age bands and gender, following the United Nations 2019 Revision of
#' World Population Prospects.
#'
#' @param country character;
#' country identifier, following the List of United Nations Member States. See \link[Bernadette]{countries_un}.
#'
#' @param year numeric;
#' calendar year.
#'
#' @return An object of class \emph{data.frame} that contains the age distribution.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2017). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
#'
#' @examples
#' # Age distribution for Greece in 2020:
#'age_distr <- age_distribution(country = "Greece", year = 2020)
#'
#' @export
age_distribution <- function(country,
                             year
){

  if(country %in% countries_un() == FALSE) stop("The user-defined country name is not available. Please check countries_un().")

  tmp_env   <- new.env()
  data_path <- paste0("https://github.com//kieshaprem//synthetic-contact-matrices//",
                      "raw//master//generate_synthetic_matrices//input//pop//",
                      "poptotal",
                      ".rdata" )
  load(base::url(data_path), envir = tmp_env)

  dem_table <- tmp_env$poptotal
  filter    <- dem_table$countryname == country & dem_table$year == year
  dem_table <- unique( dem_table[filter, ] )

  dem_table$total <- NULL

  dem_table_long <- stats::reshape(dem_table,
                                   direction = "long",
                                   varying   = list(names(dem_table)[4:ncol(dem_table)]),
                                   v.names   = "PopTotal",
                                   idvar     = c("iso3c", "countryname", "year"),
                                   timevar   = "AgeGrpStart",
                                   times     = colnames(dem_table)[-c(1:3)])

  rownames(dem_table_long) <- NULL
  dem_table_long$AgeGrpStart <- as.numeric( gsub("age", "", dem_table_long$AgeGrpStart))

  dem_table_pre70  <- dem_table_long[dem_table_long$AgeGrpStart < 75,]
  dem_table_75plus <- dem_table_long[dem_table_long$AgeGrpStart >= 75,]

  dem_table_75plus <- cbind(dem_table_75plus[1, c("iso3c", "countryname", "year", "AgeGrpStart")],
                  data.frame(PopTotal = sum(dem_table_75plus$PopTotal)))

  dem_table_75plus$AgeGrp <- "75+"

  dem_table_pre70$AgeGrp      <- dem_table_pre70$AgeGrpStart + 4
  dem_table_pre70$AgeGrp      <- paste0(dem_table_pre70$AgeGrpStart, "-", dem_table_pre70$AgeGrp)

  #----------------
  out                <- rbind(dem_table_pre70, dem_table_75plus)
  out                <- as.data.frame(out)
  out$iso3c          <- as.character(out$iso3c)
  out$countryname    <- as.character(out$countryname)
  colnames(out)[1:3] <- c("iso3c", "Location", "Time")

  out <- out[c("Location", "Time", "AgeGrp", "AgeGrpStart", "PopTotal")]

  return(out)

}# End function
