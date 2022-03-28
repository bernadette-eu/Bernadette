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
#'analysis_AgeGrp <- data.frame(REACT = c("15-44", "45-64", "65-74", "75+"),
#'                              User  = c(rep("0-44", 1),
#'                                       rep("45-64", 2),
#'                                       rep("65+",   1)))
#'
#'# Aggregate the IFR:
#'aggr_age <- aggregate_ifr_react(age_distr, analysis_AgeGrp)
#'
#'}
#'
#' @export
aggregate_ifr_react <- function(x,
                                user_AgeGrp){

  options(dplyr.summarise.inform = FALSE)

  react_AgeGrp <- c("15-44", "45-64", "65-74", "75+")

  if( length(user_AgeGrp$REACT) == length(react_AgeGrp) &
      isTRUE(all.equal(user_AgeGrp$REACT, react_AgeGrp)) == FALSE ) stop("Provide mapping for the REACT study age groups [15-44, 45-64, 65-74, 75+].")

  temp_x <- x
  temp_x$AgeGrp    <- gsub("\\+", "-100", temp_x$AgeGrp)
  temp_x$AgeGrpEnd <- sapply(1:nrow(temp_x), function(x){max(as.numeric(strsplit(temp_x$AgeGrp, "-")[[x]]))})

  ifr_react <- data.frame(AgeGrp = c("15-44", "45-64", "65-74", "75-100"),
                          IFR    = c(0.03, 0.52, 3.13, 11.64)/100)
  ifr_react$AgeGrpStart <- sapply(1:nrow(ifr_react), function(x){min(as.numeric(strsplit(ifr_react$AgeGrp, "-")[[x]]))})
  ifr_react$AgeGrpEnd   <- sapply(1:nrow(ifr_react), function(x){max(as.numeric(strsplit(ifr_react$AgeGrp, "-")[[x]]))})

  #ifr_react$PopPerc <- 0

  for (i in 1:nrow(ifr_react)){

    if (i == 1) select_indx <- temp_x$AgeGrpEnd <= ifr_react$AgeGrpEnd[i]
    else select_indx <- (temp_x$AgeGrpStart >= ifr_react$AgeGrpStart[i]) &
                        (temp_x$AgeGrpEnd   <= ifr_react$AgeGrpEnd[i])

    ifr_react$PopN[i] <- sum(temp_x$PopTotal[select_indx])

  }# End for

  ifr_react$AgeGrp <- gsub("\\-100", "+", ifr_react$AgeGrp)

  output <- list()

  output[[1]] <- ifr_react

  output[[2]] <- ifr_react %>% as.data.frame() %>%
                 dplyr::left_join(user_AgeGrp,
                                  by = c("AgeGrp" = "REACT")) %>%
                 dplyr::group_by(User) %>%
                 dplyr::mutate(PopPerc = prop.table(PopN),
                               AgrIFR = sum(IFR*PopPerc)) %>%
                 dplyr::rename(REACT_AgeGrp = AgeGrp,
                               User_AgeGrp  = User) %>%
                 dplyr::select(dplyr::one_of(c("User_AgeGrp", "AgrIFR")) ) %>%
                 dplyr::group_by(User_AgeGrp, AgrIFR) %>%
                 dplyr::slice(1) %>% as.data.frame()

  return(output)
}

