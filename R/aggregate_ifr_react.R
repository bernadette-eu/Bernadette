#' Aggregate the Infection Fatality Ratio
#'
#' Function to aggregate the Infection Fatality Ratio (IFR) by age from REACT according to user-defined age groups.
#'
#' @param x data.frame; an age distribution matrix. See \link[Bernadette]{age_distribution}.
#'
#' @param user_AgeGrp data.frame; a user-defined dataframe which maps the four age groups to a new set of age groups.
#'
#' @return A list of two data frames that contains the aggregated IFR estimates.
#'
#' @references
#' Ward, H., Atchison, C., Whitaker, M. et al. (2021). SARS-CoV-2 antibody prevalence in England following the first peak of the pandemic. Nature Communications 12, 905
#'
#' @examples
#'
#' \dontrun{
#'# Import the age distribution for a country in a given year:
#'age_distr <- age_distribution(country = "Greece",
#'                              year    = 2020)
#'
# Lookup table:
#'age_mapping <- c(rep("0-39",  8),
#'                 rep("40-64", 5),
#'                 rep("65+",   3))
#'
#'# Aggregate the IFR:
#'aggr_age <- aggregate_ifr_react(age_distr, age_mapping)
#'
#'}
#'
#' @export
aggregate_ifr_react <- function(x,
                                user_AgeGrp,
                                data_cases){

  options(dplyr.summarise.inform = FALSE)

  if( length(user_AgeGrp) != nrow(x) ) stop("The mapped age group labels do not correspond to the age group labels of the aggregated age distribution matrix.\n")

  ifr_react <- data.frame(AgeGrp = c("0-14","15-44", "45-64", "65-74", "75-100"),
                          IFR    = c(0, 0.03, 0.52, 3.13, 11.64)/100)

  ifr_react$AgeGrpStart <- sapply(1:nrow(ifr_react), function(x){min(as.numeric(strsplit(ifr_react$AgeGrp, "-")[[x]]))})
  ifr_react$AgeGrpEnd   <- sapply(1:nrow(ifr_react), function(x){max(as.numeric(strsplit(ifr_react$AgeGrp, "-")[[x]]))})

  temp_x <- x
  temp_x$AgeGrp        <- gsub("\\+", "-100", temp_x$AgeGrp)
  temp_x$AgeGrpEnd     <- sapply(1:nrow(temp_x), function(x){max(as.numeric(strsplit(temp_x$AgeGrp, "-")[[x]]))})
  temp_x$IFR           <- rep(0,nrow(temp_x))
  temp_x$Group_mapping <- user_AgeGrp

  output <- list()

  # English data (population Europe Website):
  if ("AgeGrpStart" %nin% colnames(temp_x) ) temp_x$AgeGrpStart <-
                                                     sapply(1:nrow(temp_x),
                                                     function(x){min(as.numeric(strsplit(temp_x$AgeGrp,
                                                                                         "-")[[x]]))})

  for (i in 1:nrow(temp_x)){
    for (j in 1:nrow(ifr_react)) {
      if ( (temp_x$AgeGrpStart[i] >= ifr_react$AgeGrpStart[j]) &
           (temp_x$AgeGrpEnd[i]   <= ifr_react$AgeGrpEnd[j]) ) temp_x$IFR[i] <- ifr_react$IFR[j]
    }# End for
  }# End for

  output[[1]] <- temp_x %>%
                  as.data.frame() %>%
                  dplyr::group_by(Group_mapping) %>%
                  dplyr::mutate(PopPerc = prop.table(PopTotal),
                                AgrIFR  = sum(IFR*PopPerc))

  #---- Time-independent IFR:
  output[[2]] <- output[[1]] %>%
                 dplyr::select(dplyr::one_of(c("Group_mapping", "AgrIFR")) ) %>%
                 dplyr::group_by(Group_mapping, AgrIFR) %>%
                 dplyr::slice(1) %>%
                 as.data.frame()

  #---- Time-dependent IFR:
  data_cases_weights <- data_cases %>%
                        dplyr::select(-dplyr::one_of(c("Date")) ) %>%
                        dplyr::mutate(across(everything()), . / Total_Cases)  %>%
                        dplyr::mutate(Date = data_cases$Date) %>%
                        dplyr::select(-dplyr::one_of(c("Total_Cases")) ) %>%
                        gather(Group, Weight, -c(Date)) %>%
                        dplyr::arrange(Date, Group) %>%
                        dplyr::left_join(output[[2]],
                                         by = c("Group" = "Group_mapping")) %>%
                        dplyr::mutate(Weighted_IFR = Weight * AgrIFR) %>%
                        dplyr::select(-dplyr::one_of(c("Weight", "AgrIFR")) )

  output[[3]] <- reshape(data_cases_weights,
                         idvar     = "Date",
                         timevar   = "Group",
                         direction = "wide")
  colnames(output[[3]]) <- gsub("Weighted_IFR.", "",
                                colnames(output[[3]]))

  return(output)
}

