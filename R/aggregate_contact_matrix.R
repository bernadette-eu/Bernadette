#' Aggregate a contact matrix
#'
#' Function to aggregate a contact matrix according to user-defined age groups.
#'
#' @param x data.frame; a contact matrix. See \link[Bernadette]{contact_matrix}.
#'
#' @param lookup_table data.frame; a user-defined dataframe which maps the sixteen 5-year age bands to a new set of age bands.
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

  if( !identical( unique(lookup_table$Mapping), age.distr$AgeGrp) ) stop("The mapped age group labels do not correspond to the age group labels of the aggregated age distribution matrix.\n")

  options(dplyr.summarise.inform = FALSE)

  long_dt <- x %>%
             as.data.frame() %>%
             tibble::rownames_to_column("indiv_age") %>%
             tidyr::pivot_longer(-c(indiv_age),
                                 names_to  = "contact_age",
                                 values_to = "contact")

  long_dt$indiv_age   <- as.factor(long_dt$indiv_age)
  long_dt$contact_age <- as.factor(long_dt$contact_age)

  long_dt <- long_dt %>%
              dplyr::left_join(lookup_table,
                               by = c("indiv_age" = "Initial")) %>%
              dplyr::rename(indiv_age_agr = Mapping) %>%
              dplyr::left_join(lookup_table,
                               by = c("contact_age" = "Initial")) %>%
              dplyr::mutate(diag_element = ifelse(indiv_age == contact_age, TRUE, FALSE)) %>%
              dplyr::rename(contact_age_agr = Mapping) %>%
              dplyr::group_by(indiv_age_agr, contact_age_agr, diag_element) %>%
              dplyr::summarise(mean_cm   = mean(contact)) %>%
              dplyr::group_by(indiv_age_agr, contact_age_agr) %>%
              dplyr::summarise(mean_cm   = sum(mean_cm))

  cm_to_rescale <- utils::unstack(long_dt[,c(1,2,3)], mean_cm ~ contact_age_agr)
  age_bands     <- length( unique(age.distr$AgeGrp) )
  out           <- matrix(0, age_bands, age_bands)

  for (i in 1:age_bands) for (j in 1:age_bands) out[i,j] <- 0.5*(1/age.distr$PopTotal[i])*(cm_to_rescale[i,j]*age.distr$PopTotal[i] + cm_to_rescale[j,i]*age.distr$PopTotal[j] )

  rownames(out) <- colnames(out) <- unique(long_dt$indiv_age_agr)

  return(out)
}
