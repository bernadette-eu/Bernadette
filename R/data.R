#' Age distribution per country
#'
#' A dataset containing the age distribution per country and per year. Information is broken
#' down by gender and 5-year age bands, following the United Nations 2019 Revision
#' of World Population Prospects.
#'
#' @format A data frame with 1,164,891 rows and 7 variables:
#' \describe{
#'   \item{Location}{character; name of country}
#'   \item{Time}{numeric; year}
#'   \item{AgeGrp}{character; 5-year age bands}
#'   \item{AgeGrpStart}{numeric; year indicating the start of the respective age group}
#'   \item{PopMale}{numeric; male population in the given age group}
#'   \item{PopFemale}{numeric; female population in the given age group}
#'   \item{PopTotal}{total population in the given age group}
#' }
#' @source \url{https://population.un.org/}
"demographics_un"

#' Contact matrices per country
#'
#' A list of 16 by 16 contact matrices for 177 countries.
#' Row i of a column j of a contact matrix corresponds to the number of contacts
#' made by an individual in group i with an individual in group j.
#'
#' @section References:
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2020). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
"contact_matrices"
