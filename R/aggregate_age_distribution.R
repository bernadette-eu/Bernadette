#' Aggregate the age distribution matrix
#'
#' Function to aggregate the age distribution according to user-defined age groups.
#'
#' @param x data.frame;
#' an age distribution matrix. See \link[Bernadette]{age_distribution}.
#'
#' @param lookup_table data.frame;
#' a user-defined dataframe which maps the sixteen 5-year age bands to a new set of age bands.
#'
#' @return A data frame that contains the aggregated age distribution.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2020). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
#'
#' @examples
#'
#' \dontrun{
#'# Import the age distribution for a country in a given year:
#'age_distr <- age_distribution(country = "Greece",
#'                              year    = 2020)
#'
# Lookup table:
#'lookup_table <- data.frame(Initial = age_distr$AgeGrp,
#'                           Mapping = c("0-17",  "0-17",  "0-17",  "0-17",
#'                                       "18-39", "18-39", "18-39", "18-39",
#'                                       "40-64", "40-64", "40-64", "40-64", "40-64",
#'                                       "65+", "65+", "65+"))
#'
#'# Aggregate the age distribution table:
#'aggr_age <- aggregate_age_distribution(age_distr, lookup_table)
#'
#'# Plot the aggregated age distribution matrix:
#'plot_age_distribution(aggr_age)
#'}
#'
#' @export
#'
aggregate_age_distribution <- function(x,
                                       lookup_table
){

  dt <- base::merge(x,
            			  lookup_table,
            			  by.x = "AgeGrp",
            			  by.y = "Initial",
            			  all.x = TRUE) %>%
        base::subset(select = !grepl("^AgeGrpStart$", names(.))) %>%
        stats::aggregate(PopTotal ~ Mapping,
                			   data = .,
                			   FUN = sum) %>%
        stats::setNames(c("AgeGrp", "PopTotal"))

  dt$Location <- rep(unique(x$Location), dim(dt)[1])
  dt$Time     <- rep(unique(x$Time),     dim(dt)[1])

  dt <- dt[c("Location", "Time", "AgeGrp", "PopTotal")]

  return(dt)

}
