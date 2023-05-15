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
#'
#' @usage data(demographics_un)
#'
"demographics_un"

#' Contact matrices per country
#'
#' A list of 16 by 16 contact matrices for 177 countries.
#' Row i of a column j of a contact matrix corresponds to the number of contacts
#' made by an individual in group i with an individual in group j.
#'
#' @usage data(contact_matrices)
#'
#' @section References:
#' Prem, K., van Zandvoort, K., Klepac, P. et al (2020). Projecting contact matrices in 177 geographical regions: an update and comparison with empirical data for the COVID-19 era. medRxiv 2020.07.22.20159772; doi: https://doi.org/10.1101/2020.07.22.20159772
"contact_matrices"

#' Age distribution of reported deaths for Greece
#'
#' A dataset containing the age distribution of reported deaths in Greece from 2020-08-31 to 2021-03-28 (30 weeks).
#' The dataset has been extracted from the Hellenic National Public Health Organization database.
#'
#' @format A data frame with 210 rows and 8 variables:
#' \describe{
#'   \item{Index}{integer; a sequence of integer numbers from 1 to 210}
#'   \item{Right}{numeric; Index + 1}
#'   \item{Date}{Date, format; date in the format "2020-08-31"}
#'   \item{Week_ID}{numeric; index of the week that each day falls into. A week is assumed to have 7 days}
#'   \item{New_Deaths}{numeric; count of total reported deaths on a given date}
#'   \item{0-39}{numeric; count of reported deaths on a given date for the age group "0-39"}
#'   \item{40-64}{numeric; count of reported deaths on a given date for the age group "40-64"}
#'   \item{65+}{numeric; count of reported deaths on a given date for the age group "65+"}
#' }
#'
#' @usage data(age_specific_mortality_counts)
#'
#' @section References:
#' Sandbird (2022). Daily regional statistics for covid19 cases in Greece.
#'
#' @source \url{https://github.com/Sandbird/covid19-Greece/}
"age_specific_mortality_counts"

#' Age distribution of reported infections for Greece
#'
#' A dataset containing the age distribution of reported infections in Greece from 2020-08-31 to 2021-03-28 (30 weeks).
#' The dataset has been extracted from the Hellenic National Public Health Organization database.
#'
#' @format A data frame with 210 rows and 8 variables:
#' \describe{
#'   \item{Index}{integer; a sequence of integer numbers from 1 to 210}
#'   \item{Right}{numeric; Index + 1}
#'   \item{Date}{Date, format; date in the format "2020-08-31"}
#'   \item{Week_ID}{numeric; index of the week that each day falls into. A week is assumed to have 7 days}
#'   \item{Total_Cases}{numeric; count of total reported infections on a given date}
#'   \item{0-39}{numeric; count of reported infections on a given date for the age group "0-39"}
#'   \item{40-64}{numeric; count of reported infections on a given date for the age group "40-64"}
#'   \item{65+}{numeric; count of reported infections on a given date for the age group "65+"}
#' }
#'
#' @usage data(age_specific_infection_counts)
#'
#' @section References:
#' Sandbird (2022). Daily regional statistics for covid19 cases in Greece.
#' @source \url{https://github.com/Sandbird/covid19-Greece/}
"age_specific_infection_counts"
