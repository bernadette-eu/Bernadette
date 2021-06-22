#' Country-specific COVID-19 daily time series summary table
#'
#' Function to extract COVID-19 daily time series summary information, based on the
#' \href{https://github.com/CSSEGISandData/COVID-19}{COVID-19 Data Repository} of the Johns
#' Hopkins University Center for Systems Science and Engineering (CSSE).
#'
#' @param country character; country identifier, following the \href{https://www.un.org/en/about-us/member-states}{List of United Nations Member States}.
#'
#' @param start_date character; calendar date in the format "yyyy-mm-dd"
#'
#' @param end_date character; calendar date in the format "yyyy-mm-dd"
#'
#' @references
#' Dong, E., Du, H., & Gardner L. (2020). An interactive web-based dashboard to track COVID-19
#' in real time. Lancet Inf Dis, 20(5), 533-534. doi: 10.1016/S1473-3099(20)30120-1
#'
#' @return  A list with components
#' \describe{
#'   \item{Cases_deaths}{A data frame at daily level, containing a date index, the date in format "yyyy-mm-dd",
#'                       the COVID-19 confirmed cumulative cases and cumulative deaths, the daily confirmed cases and the daily deaths.}
#'   \item{Date_range}{A vector of dates in the format "yyyy-mm-dd", from the selected time series.}
#' }
#'
#' @examples
#'
#' \dontrun{
#' cd <- import_cases_deaths(country    = "Greece",
#'                           start_date = "2020-03-05",
#'                           end_date   = "2020-10-07"
#'                           )
#'}
#'
#' @export
#'
import_cases_deaths <- function(country,
                                start_date  = NULL,
                                end_date    = NULL
){

 if (is.null(country)) stop("Please specify the country of interest.")

 if (is.null(start_date) & is.null(end_date)) message("Time series start and end date are not specified.\n The whole time series will be considered.")

  repo         <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/"

  cumul_deaths <- readr::read_csv( paste0(repo, "time_series_covid19_deaths_global",   ".csv"), col_types = readr::cols() )
  cumul_cases  <- readr::read_csv( paste0(repo, "time_series_covid19_confirmed_global",".csv"), col_types = readr::cols() )

  cumul_deaths <- data.frame( t( cumul_deaths[cumul_deaths[,2] == country,] ), stringsAsFactors = FALSE )
  cumul_cases  <- data.frame( t( cumul_cases[cumul_cases[,2]   == country,] ), stringsAsFactors = FALSE )

  colnames(cumul_deaths) <- "Cumulative_Deaths"
  colnames(cumul_cases)  <- "Cumulative_Cases"

  if ( nrow(cumul_deaths) != nrow(cumul_cases) ) stop("The time series for the cumulative cases and deaths are not of the same length.")

  dt_cd <- cbind(cumul_deaths, cumul_cases)
  dt_cd <- dt_cd[-c(1:4),]

  dt_cd[,1:2] <- data.frame( sapply( dt_cd[,1:2], as.numeric ) )

  dt_cd$Date <- lubridate::mdy(rownames(dt_cd))

  if ( nrow(cumul_deaths) != nrow(cumul_cases) ) stop("The time series for the cumulative cases and deaths are not of the same length.")

  if (is.character(start_date) & is.character(end_date) ){

    dt_cd  <- dt_cd[dt_cd$Date >= start_date & dt_cd$Date <= end_date,]

  } else if( is.null(start_date) & is.character(end_date) ){

    dt_cd  <- dt_cd[dt_cd$Date <= end_date,]

  } else if( is.character(start_date) & is.null(end_date) ){

    dt_cd  <- dt_cd[dt_cd$Date >= start_date,]

  }

  ts_len <- nrow(dt_cd)
  dt_cd$Ts_index <- 1:ts_len

  cases <- deaths <- rep(0, ts_len)

  cases[1] <- dt_cd$Cumulative_Cases[1]
  for (t in 2:ts_len){
    cases[t] <- dt_cd$Cumulative_Cases[t] - dt_cd$Cumulative_Cases[t-1]
  }

  deaths[1] <- dt_cd$Cumulative_Deaths[1]

  for (t in 2:ts_len){
    deaths[t] <- dt_cd$Cumulative_Deaths[t] - dt_cd$Cumulative_Deaths[t-1]
    if (deaths[t] < 0) deaths[t] <- 0
  }

  dt_cd$New_Cases  <- cases
  dt_cd$New_Deaths <- deaths
  rownames(dt_cd)  <- NULL

  dt_cd <- dt_cd[c("Ts_index",
                   "Date",
                   "Cumulative_Cases",
                   "New_Cases",
                   "Cumulative_Deaths",
                   "New_Deaths")]

  out <- list(Cases_deaths = dt_cd,
              Date_range   = dt_cd$Date)

  return(out)

}
