#' Aggregate a contact matrix
#'
#' Function to aggregate a contact matrix according to user-defined age groups.
#'
#' @param object data.frame;
#' a contact matrix. See \link[Bernadette]{contact_matrix}.
#'
#' @param lookup_table data.frame;
#' a user-defined data.frame which maps the sixteen 5-year age bands to a new set of age bands.
#'
#' @param age_distr data.frame;
#' the aggregated age distribution. See \link[Bernadette]{aggregate_contact_matrix}.
#'
#' @return An object of class \emph{data.frame}.
#'
#' @examples
#' # Import the age distribution for Greece in 2020:
#' age_distr <- age_distribution(country = "Greece", year = 2020)
#'
#' # Lookup table:
#' lookup_table <- data.frame(Initial = age_distr$AgeGrp,
#'                            Mapping = c(rep("0-39",  8),
#'                                        rep("40-64", 5),
#'                                        rep("65+"  , 3)))
#'
#' # Aggregate the age distribution table:
#' aggr_age <- aggregate_age_distribution(age_distr, lookup_table)
#'
#' # Import the projected contact matrix for Greece:
#' conmat <- contact_matrix(country = "GRC")
#'
#' # Aggregate the contact matrix:
#' aggr_cm <- aggregate_contact_matrix(conmat, lookup_table, aggr_age)
#'
#' # Plot the contact matrix:
#' plot_contact_matrix(aggr_cm)
#'
#' @export
#'
aggregate_contact_matrix <- function(object,
                                     lookup_table,
                                     age_distr
){
 if (!identical(unique(lookup_table$Mapping), age_distr$AgeGrp)) {
    stop("The mapped age group labels do not correspond to the age group labels of the aggregated age distribution matrix.\n")
  }
  indiv_age_df <- base::data.frame(indiv_age = lookup_table$Initial)
  object_df <- cbind(object, indiv_age_df)
  long_dt <- stats::reshape(object_df, varying = list(base::names(object_df)[-ncol(object_df)]), 
                            direction = "long", sep = "_", timevar = "contact_age", 
                            times = base::names(object_df)[-ncol(object_df)], v.names = "contact")
  long_dt$id <- NULL
  
  long_dt$indiv_age <- as.factor(long_dt$indiv_age)
  long_dt$contact_age <- as.factor(long_dt$contact_age)
  names(lookup_table) <- c("indiv_age", "indiv_age_agr")
  
  long_dt <- base::merge(long_dt, lookup_table, by = "indiv_age", 
                         all.x = TRUE)
  
  names(lookup_table) <- c("contact_age", "contact_age_agr")
  
  long_dt <- base::merge(long_dt, lookup_table, by = "contact_age", 
                         all.x = TRUE)
  
  long_dt$diag_element <- ifelse(long_dt$indiv_age == long_dt$contact_age, 
                                 TRUE, FALSE)
  
  dt_aggregate <- stats::aggregate(long_dt$contact, by = list(long_dt$indiv_age_agr, 
                                                              long_dt$contact_age_agr, long_dt$diag_element), mean)
  names(dt_aggregate) <- c("indiv_age_agr", "contact_age_agr", 
                           "diag_element", "mean_cm")
  
  dt_aggregate <- stats::aggregate(dt_aggregate$mean_cm, by = list(dt_aggregate$indiv_age_agr, 
                                                                   dt_aggregate$contact_age_agr), sum)
  
  names(dt_aggregate) <- c("indiv_age_agr", "contact_age_agr", 
                           "mean_cm")
  
  cm_to_rescale <- as.matrix(stats::reshape(dt_aggregate, 
                                            idvar     = "indiv_age_agr", 
											timevar   = "contact_age_agr", 
                                            direction = "wide"))
  cm_to_rescale <- cm_to_rescale[, 2:ncol(cm_to_rescale)]
  
  class(cm_to_rescale) <- "numeric"
  
  age_bands <- length(unique(age_distr$AgeGrp))
  ret <- matrix(0, age_bands, age_bands)
  
  for (i in seq(1, age_bands, 1)) {
    for (j in seq(1, age_bands, 1)) {
      ret[i, j] <- 0.5 * (1/age_distr$PopTotal[i]) * (cm_to_rescale[i,j] * age_distr$PopTotal[i] + 
	               cm_to_rescale[j, i] * age_distr$PopTotal[j])
    }
  }
  rownames(ret) <- colnames(ret) <- age_distr$AgeGrp
  ret <- as.data.frame(ret)
  
  return(ret)
}
