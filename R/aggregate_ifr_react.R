#' Aggregate the Infection Fatality Ratio
#'
#' Function to aggregate the age-specific Infection Fatality Ratio (IFR) estimates reported by the REACT-2 large-scale community study of SARS-CoV-2 seroprevalence in England according to user-defined age groups.
#'
#' @param x data.frame;
#' an age distribution matrix. See \link[Bernadette]{age_distribution}.
#'
#' @param user_AgeGrp vector;
#' a user-defined vector which maps the four age groups considered in REACT-2 to a new set of age groups.
#'
#' @param data_cases data.frame;
#' time series dataset containing the age-stratified infection counts. See \link[Bernadette]{age_specific_infection_counts}.
#'
#' @return A list of two data frames that contains the aggregated IFR estimates.
#'
#' @references
#' Ward, H., Atchison, C., Whitaker, M. et al. (2021). SARS-CoV-2 antibody prevalence in England following the first peak of the pandemic. Nature Communications 12, 905
#'
#' @examples
#' # Import the age distribution for Greece in 2020:
#' age_distr <- age_distribution(country = "Greece", year = 2020)
#'
#  Lookup table:
#' age_mapping <- c(rep("0-39",  8),
#'                  rep("40-64", 5),
#'                  rep("65+",   3))
#'
#' data(age_specific_infection_counts)
#'
#' # Aggregate the IFR:
#' aggr_age_ifr <- aggregate_ifr_react(age_distr, age_mapping, age_specific_infection_counts)
#'
#' @export
#'
aggregate_ifr_react <- function(x,
                                user_AgeGrp,
                                data_cases){

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

  # Group data by Group_mapping and calculate PopPerc and AgrIFR using base R functions
  pop_total   <- tapply(temp_x$PopTotal, temp_x$Group_mapping, sum)
  output[[1]] <- base::transform(temp_x,
                                 PopPerc = ave(PopTotal, Group_mapping, FUN = function(x) prop.table(x)) )
  output[[1]] <- base::transform(output[[1]],
                                 AgrIFR  = ave(IFR * PopPerc, Group_mapping, FUN = sum))

  #---- Time-independent IFR:
  output[[2]] <- aggregate(AgrIFR ~ Group_mapping, output[[1]], FUN = function(x) x[1])

  #---- Time-dependent IFR:
  data_cases_weights <- data_cases[, !(colnames(data_cases) %in% c("Index", "Right", "Week_ID"))]
  data_cases_weights <- cbind(data_cases_weights[, "Date", drop = FALSE],
                              data.frame(sapply(data_cases_weights[, -1, drop = FALSE], function(x) x / data_cases$Total_Cases)))
  data_cases_weights$Date <- data_cases$Date
  data_cases_weights <- data_cases_weights[, !(names(data_cases_weights) %in% "Total_Cases")]

  colnames(data_cases_weights)[2:length(colnames(data_cases_weights))] <- output[[2]]$Group_mapping

  data_cases_weights <- stats::reshape(data_cases_weights,
                                       direction = "long",
                                       varying   = list(names(data_cases_weights)[2:ncol(data_cases_weights)]),
                                       v.names   = "Weight",
                                       idvar     = c("Date"),
                                       timevar   = "Group",
                                       times     = colnames(data_cases_weights)[-1])
  rownames(data_cases_weights) <- NULL

  data_cases_weights <- data_cases_weights[order(data_cases_weights$Date, data_cases_weights$Group), ]
  data_cases_weights <- base::merge(data_cases_weights,
                                    output[[2]],
                                    by.x  = "Group",
                                    by.y  = "Group_mapping",
                                    all.x = TRUE)
  data_cases_weights$Weighted_IFR <- with(data_cases_weights, Weight * AgrIFR)
  data_cases_weights <- data_cases_weights[, !(names(data_cases_weights) %in% c("Weight", "AgrIFR"))]

  output[[3]] <- stats::reshape(data_cases_weights,
                                idvar     = "Date",
                                timevar   = "Group",
                                direction = "wide")
  colnames(output[[3]]) <- gsub("Weighted_IFR.", "", colnames(output[[3]]))

  output[[3]] <- output[[3]][order(output[[3]]$Date), ]

  return(output)
}

