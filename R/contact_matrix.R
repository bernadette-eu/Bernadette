#' Country-specific contact matrix
#'
#' A 16 by 16 contact matrix whose row i of a column j corresponds to the number of contacts
#' made by an individual in group i with an individual in group j.
#'
#' @param country
#' A character indicating the country identifier. See \link[Bernadette]{country_contact_matrices}.
#'
#' @return An object of class "data.frame".
#'
#' @references
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2020). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
#'
#' @examples
#'
#' \dontrun{
#' conmat <- contact_matrix(country = "GRC")
#'}
#'
#' @export
contact_matrix <- function(country){

  if(country %in% country_contact_matrices() == FALSE) stop("The user-defined country name is not available. Please check country_contact_matrices().")

  tmp_env <- new.env()

  utils::data(contact_matrices, envir = tmp_env)

  contact_matrix <- data.frame(tmp_env$contact_matrices[[country]] )

  age_groups <- c("0-4",
                  "5-9",
                  "10-14",
                  "15-19",
                  "20-24",
                  "25-29",
                  "30-34",
                  "35-39",
                  "40-44",
                  "45-49",
                  "50-54",
                  "55-59",
                  "60-64",
                  "65-69",
                  "70-74",
                  "75+")
  rownames(contact_matrix) <- colnames(contact_matrix) <- age_groups

  return(contact_matrix)
}
