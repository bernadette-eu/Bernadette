# Age-specific mortality and infection counts -------------------------

library(magrittr)
library(dplyr, warn.conflicts = FALSE)
library(rvest)
library(readr)
library(usethis)

# Age mapping of the deaths:
age_mapping_deaths <- c(rep("0-39", 2), "40-64", "65+")

# Mapping of the age distribution:
age_mapping_UN <- c(rep("0-39",  8),
                    rep("40-64", 5),
                    rep("65+",   3))

#---- Country and analysis period:
country    <- "Greece"
start_date <- "2020-08-31"
end_date   <- "2021-03-28"

#---- Data engineering; daily time series of new cases and deaths for a given period:
data_engineering_observations_GR <- function(start_date  = NULL,
                                             end_date    = NULL,
                                             age_mapping_deaths
){

  if (is.null(start_date) &
      is.null(end_date)) message("Time series start and end date are not specified.\n The whole time series will be considered.")

  repo <- "https://raw.githubusercontent.com/Sandbird/covid19-Greece/master/"

  data <- readr::read_csv( paste0(repo, "demography_total_details", ".csv"), col_types = readr::cols() )

  # The data start from 2020-04-03
  data <- subset(data, date >= "2020-04-03")

  #---- Calculate the new deaths and cases per age group:
  data_groups_cols             <- c("Date", "Group", "Cumul_cases", "Cumul_deaths")#, "Cumul_cases", "Total_Cases", "Cumul_deaths", "New_Deaths")
  dt_analysis_period           <- data.frame(matrix(ncol = length(data_groups_cols), nrow = 0))
  colnames(dt_analysis_period) <- data_groups_cols

  #---- Rename the columns according to the mapping:
  #age_mapping_deaths <- c(rep("0-39", 2), "40-64", "65+")
  lookup_table <- data.frame(Initial = unique(data$category),
                             Mapping = age_mapping_deaths)
  age_bands    <- unique(unique(lookup_table$Mapping))
  age_bands_no <- length(age_bands)
  dates        <- unique(data$date)

  data_melt <- data %>%
                dplyr::left_join(lookup_table,
                                 by = c(category = "Initial")) %>%
                dplyr::select(-dplyr::one_of(c("category"))) %>%
                dplyr::group_by(date, Mapping) %>%
                dplyr::summarise(Cumul_cases  = sum(cases),
                                 Cumul_deaths = sum(deaths)) %>%
                dplyr::rename(Group = Mapping)

  for ( i in seq(1, age_bands_no, 1) ){

    data_subset <- data_melt[data_melt$Group == age_bands[i],]

    dt_age_grp <- data.frame(Date         = dates,
                             Group        = rep(age_bands[i], length(dates)),
                             Cumul_cases  = c(data_subset[data_subset$Group == age_bands[i],"Cumul_cases"]),
                             Cumul_deaths = c(data_subset[data_subset$Group == age_bands[i],"Cumul_deaths"])
    )

    # Calculate new deaths and cases from the cumulative deaths and cases, respectively:
    new_cases_age_grp    <- rep(0, nrow(dt_age_grp))
    new_cases_age_grp[1] <- data_subset$Cumul_cases[1]

    new_deaths_age_grp    <- rep(0, nrow(dt_age_grp))
    new_deaths_age_grp[1] <- data_subset$Cumul_deaths[1]

    for (t in seq(2, length(dates), 1) ) {
      new_cases_age_grp[t]  <- data_subset$Cumul_cases[t]  - data_subset$Cumul_cases[t-1]
      new_deaths_age_grp[t] <- data_subset$Cumul_deaths[t] - data_subset$Cumul_deaths[t-1]

      # Sanity check - if the cumulative cases/deaths are lower than the day before, set to zero.
      # Confirmed by EODY reports for the dates 2020-04-09 (65+), 2020-05-05 (40-64), 2020-05-21 (40-64), 2020-05-27 (65+)
      if(new_cases_age_grp[t] < 0)  new_cases_age_grp[t]  <- 0
      if(new_deaths_age_grp[t] < 0) new_deaths_age_grp[t] <- 0

    }# End for

    dt_age_grp$Total_Cases <- new_cases_age_grp
    dt_age_grp$New_Deaths  <- new_deaths_age_grp

    dt_analysis_period <- rbind(dt_analysis_period, dt_age_grp)

  }# End for

  #---- Subset for the analysis period:
  dt_analysis_period <- dt_analysis_period[ dt_analysis_period$Date >= as.Date(start_date, format = "%Y-%m-%d") &
                                            dt_analysis_period$Date <= as.Date(end_date, format = "%Y-%m-%d"),]

  #---- Mortality data to be processed by the .stan file:
  dt_mortality_analysis_period <- reshape(dt_analysis_period[,c(1,2,ncol(dt_analysis_period))],
                                          idvar     = "Date",
                                          timevar   = "Group",
                                          direction = "wide")
  colnames(dt_mortality_analysis_period) <- gsub("New_Deaths.", "",
                                                 colnames(dt_mortality_analysis_period))

  dt_mortality_analysis_period <- dt_mortality_analysis_period %>%
                                  dplyr::select(-dplyr::one_of(c("Date"))) %>%
                                  dplyr::mutate(New_Deaths = rowSums(.))

  #---- Incidence data to be processed by the .stan file:
  dt_cases_analysis_period <- stats::reshape(dt_analysis_period[,c(1,2,ncol(dt_analysis_period)-1)],
                                             idvar     = "Date",
                                             timevar   = "Group",
                                             direction = "wide")
  colnames(dt_cases_analysis_period) <- gsub("Total_Cases.", "", colnames(dt_cases_analysis_period))

  dt_cases_analysis_period <- dt_cases_analysis_period %>%
                              dplyr::select(-dplyr::one_of(c("Date"))) %>%
                              dplyr::mutate(Total_Cases = rowSums(.))

  # Additional fields:
  date_subset <- unique(dt_analysis_period$Date)

  dt_mortality_analysis_period$Date  <- date_subset
  dt_cases_analysis_period$Date      <- dt_mortality_analysis_period$Date

  dt_mortality_analysis_period$Index <- 1:nrow(dt_mortality_analysis_period)
  dt_cases_analysis_period$Index     <- 1:nrow(dt_cases_analysis_period)

  #---- Add Week ID since first day of analysis:
  # Search: Stackoverflow "How can I group days into weeks"
  dt_mortality_analysis_period$Week_ID <- as.numeric(dt_mortality_analysis_period$Date - dt_mortality_analysis_period$Date[1]) %/% 7 + 1
  dt_cases_analysis_period$Week_ID     <- as.numeric(dt_cases_analysis_period$Date - dt_cases_analysis_period$Date[1]) %/% 7 + 1

  #---- Left and right time limit:
  dt_mortality_analysis_period$Right <- dt_mortality_analysis_period$Index + 1
  dt_cases_analysis_period$Right     <- dt_cases_analysis_period$Index + 1

  #---- Re-order the column names"
  fixed_cols        <- c("Index", "Right", "Date", "Week_ID")
  fixed_cols_cases  <- c(fixed_cols, "Total_Cases")
  fixed_cols_deaths <- c(fixed_cols, "New_Deaths")

  reorder_colnames <- c(fixed_cols_cases, colnames(dt_cases_analysis_period)[!colnames(dt_cases_analysis_period) %in% fixed_cols_cases])
  dt_cases_analysis_period <- dt_cases_analysis_period[reorder_colnames]

  reorder_colnames <- c(fixed_cols_deaths, colnames(dt_mortality_analysis_period)[!colnames(dt_mortality_analysis_period) %in% fixed_cols_deaths])
  dt_mortality_analysis_period <- dt_mortality_analysis_period[reorder_colnames]

  #--- Table at level (Date-Group) with the cumulative cases (overall and dissaggregated) for the analysis period:
  data_cumcases_wide <- as.data.frame(data_melt[,c(1,2,3)])
  data_cumcases_wide <- stats::reshape(data_cumcases_wide,
                                       idvar     = "date",
                                       timevar   = "Group",
                                       direction = "wide")
  colnames(data_cumcases_wide) <- gsub("Cumul_cases.", "",
                                       colnames(data_cumcases_wide))
  colnames(data_cumcases_wide)[1] <- "Date"

  data_cumcases_wide <- data_cumcases_wide %>%
                        dplyr::select(-dplyr::one_of(c("Date"))) %>%
                        dplyr::mutate(Total_Cases = base::rowSums(.))

  data_cumcases_wide$Date  <- dates

  fixed_cols_cumcases <- c("Date", "Total_Cases")
  reorder_colnames_cumcases <- c(fixed_cols_cumcases, colnames(data_cumcases_wide)[!colnames(data_cumcases_wide) %in% fixed_cols_cumcases])

  data_cumcases_wide <- data_cumcases_wide[reorder_colnames_cumcases]

  data_cumcases_wide <- data_cumcases_wide[ data_cumcases_wide$Date >= as.Date(start_date, format = "%Y-%m-%d") &
                                            data_cumcases_wide$Date <= as.Date(end_date,   format = "%Y-%m-%d"),]

  output_list <- list(Deaths      = dt_mortality_analysis_period,
                      Cases       = dt_cases_analysis_period,
                      All         = dt_analysis_period,
                      Cumul_Cases = data_cumcases_wide)

  return(output_list)

}# End function

###########################################################################
#
# 1. Data import (mortality and incidence)
#
###########################################################################
data_all <- data_engineering_observations_GR(start_date     = start_date,
                                             end_date       = end_date,
                                             age_mapping    = age_mapping_deaths)

age_specific_mortality_counts       <- data_all$Deaths
age_specific_infection_counts       <- data_all$Cases
age_specific_cusum_infection_counts <- data_all$Cumul_Cases

# Export:
usethis::use_data(age_specific_mortality_counts,       overwrite = TRUE)
usethis::use_data(age_specific_infection_counts,       overwrite = TRUE)
usethis::use_data(age_specific_cusum_infection_counts, overwrite = TRUE)
