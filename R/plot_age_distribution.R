#' Plot the age distribution
#'
#' @param x data.frame; the age distribution matrix. See \link[Bernadette]{age_distribution} and \link[Bernadette]{aggregate_age_distribution}.
#'
#' @references
#' United Nations, Department of Economic and Social Affairs, Population Division (2019). World Population Prospects 2019, Online Edition. Rev. 1.
#'
#' @examples
#'
#' \dontrun{
#'# Plot the age distribution:
#'age_distr <- age_distribution(country = "Greece",
#'                              year    = 2020)
#'
#'plot_age_distribution(age_distr)
#'
# Lookup table:
#'lookup_table <- data.frame(Initial = age_distr$AgeGrp,
#'                           Mapping = c("0-17",  "0-17",  "0-17",  "0-17",
#'                                       "18-39", "18-39", "18-39", "18-39",
#'                                       "40-64", "40-64", "40-64", "40-64", "40-64",
#'                                       " 65+", "65+", "65+"))
#'
#'# Aggregate the age distribution table:
#'aggr_age <- aggregate_age_distribution(age_distr,
#'                                       lookup_table)
#'
#'# Plot the aggregated age distribution matrix:
#'plot_age_distribution(aggr_age)
#'
#'}
#'
#' @export
#'
plot_age_distribution <- function(x) {

  percentage_data <- x %>%
                     dplyr::select(one_of(c("AgeGrp", "PopTotal"))) %>%
                     dplyr::summarise(proportion = PopTotal/sum(PopTotal))
  percentage_data$AgeGrp <- x$AgeGrp

  levs <- as.factor( percentage_data$AgeGrp )
  levs <- factor(levs, levels = percentage_data$AgeGrp)

  out <- percentage_data %>%
         ggplot2::ggplot(aes(x = AgeGrp,
                             y = proportion)) +
         ggplot2::geom_bar(stat = "identity", fill = "steelblue4") +
         ggplot2::xlim(levs) +
         ggplot2::xlab("Age group (years)") +
         ggplot2::ylab("Proportion of the population") +
         ggplot2::scale_y_continuous(labels = scales::percent) +
         ggplot2::theme_bw()

  return(out)
}
