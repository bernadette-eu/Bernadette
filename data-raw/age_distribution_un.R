# UN age distribution -------------------------

library(dplyr, warn.conflicts = FALSE)
library(rvest)
library(tidyr)
library(readr)
library(usethis)

data_path <- paste0("https://population.un.org/wpp/Download/Files/",
                    "1_Indicators%20(Standard)/CSV_FILES/",
                    "WPP2019_PopulationByAgeSex_OtherVariants",
                    ".csv" )

demographics_un    <- readr::read_csv(data_path, col_types = readr::cols() )

keep_cols <- c("Location",
               "Time",
               "AgeGrp",
               "AgeGrpStart",
               "PopMale",
               "PopFemale",
               "PopTotal" )

pop_cols    <- c("PopMale", "PopFemale", "PopTotal")

demographics_un[,pop_cols] <- demographics_un[,pop_cols]*1000
demographics_un            <- demographics_un[, keep_cols]

# Sanity check:
data_filter <- demographics_un$Location == "Greece" & demographics_un$Time == 2020
demographics_un_gr   <- unique(demographics_un[data_filter,])

colSums(demographics_un_gr[,pop_cols])

# EXport:
usethis::use_data(demographics_un, overwrite = TRUE)
