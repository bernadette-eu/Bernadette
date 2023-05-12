#' Aggregate a contact matrix
#'
#' Function to aggregate a contact matrix according to user-defined age groups.
#'
#' @param x data.frame; a contact matrix. See \link[Bernadette]{contact_matrix}.
#'
#' @param lookup_table data.frame; a user-defined data.frame which maps the sixteen 5-year age bands to a new set of age bands.
#'
#' @param age.distr data.frame; the aggregated age distribution. See \link[Bernadette]{aggregate_contact_matrix}.
#'
#' @return An object of class "data.frame".
#'
#' @examples
#'
#' \dontrun{
#'# Import the projected contact matrix for a country:
#'cm <- contact_matrix(country = "GRC")
#'
#'# Import the age distribution for a country in a given year:
#'age_distr <- age_distribution(country = "Greece",
#'                              year    = 2020)
#'
# Lookup table:
#'lookup_table <- data.frame(Initial = colnames(cm),
#'                           Mapping = c("0-17",  "0-17",  "0-17",  "0-17",
#'                                       "18-39", "18-39", "18-39", "18-39",
#'                                       "40-64", "40-64", "40-64", "40-64", "40-64",
#'                                       "65+", "65+", "65+"))
#'
#'# Aggregate the age distribution table:
#'aggr_age <- aggregate_age_distribution(age_distr,
#'                                       lookup_table)
#'
#'# Aggregate the contact matrix:
#'aggr_cm <- aggregate_contact_matrix(cm,
#'                                    lookup_table,
#'                                    age.distr = aggr_age)
#'
#'# Plot the contact matrix:
#'plot_contact_matrix(aggr_cm)
#'}
#'
#' @export
aggregate_contact_matrix <- function(x,
                                     lookup_table,
                                     age.distr
){

  if(!identical(unique(lookup_table$Mapping), age.distr$AgeGrp)) {
    stop("The mapped age group labels do not correspond to the age group labels of the aggregated age distribution matrix.\n")
  }

  long_dt           <- as.data.frame(x)
  long_dt$indiv_age <- rownames(x)

  long_dt <- stats::reshape(long_dt,
                            varying   = list(names(long_dt)[-ncol(long_dt)]),
                            direction = "long",
                            sep       = "_",
                            timevar   = "contact_age",
                            times     = colnames(long_dt)[-ncol(long_dt)],
                            v.names   = "contact")
  long_dt$id <- NULL

  long_dt$indiv_age   <- as.factor(long_dt$indiv_age)
  long_dt$contact_age <- as.factor(long_dt$contact_age)

  names(lookup_table) <- c("indiv_age", "indiv_age_agr")
  long_dt <- base::merge(long_dt, lookup_table, by = "indiv_age", all.x = TRUE)

  names(lookup_table) <- c("contact_age", "contact_age_agr")
  long_dt <- base::merge(long_dt, lookup_table, by = "contact_age", all.x = TRUE)

  long_dt$diag_element <- ifelse(long_dt$indiv_age == long_dt$contact_age, TRUE, FALSE)

  dt <- stats::aggregate(long_dt$contact, by = list(long_dt$indiv_age_agr, long_dt$contact_age_agr, long_dt$diag_element), mean)
  names(dt) <- c("indiv_age_agr", "contact_age_agr", "diag_element", "mean_cm")

  dt <- stats:aggregate(dt$mean_cm, by = list(dt$indiv_age_agr, dt$contact_age_agr), sum)
  names(dt) <- c("indiv_age_agr", "contact_age_agr", "mean_cm")

  cm_to_rescale <- as.matrix(reshape(dt, idvar = "indiv_age_agr", timevar = "contact_age_agr", direction = "wide"))

  cm_to_rescale <- cm_to_rescale[,2:ncol(cm_to_rescale)]
  class(cm_to_rescale) <- "numeric"

  age_bands <- length(unique(age.distr$AgeGrp))
  out <- matrix(0, age_bands, age_bands)

  for (i in seq(1, age_bands, 1)) {
    for (j in seq(1, age_bands, 1)) {
      out[i,j] <- 0.5*(1/age.distr$PopTotal[i])*(cm_to_rescale[i,j]*age.distr$PopTotal[i] + cm_to_rescale[j,i]*age.distr$PopTotal[j])
    }
  }

  rownames(out) <- colnames(out) <- unique(long_dt$indiv_age_agr)

  return(out)
}
