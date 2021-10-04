#' Contact matrix heatmap
#'
#' @param x data.frame; a contact matrix.  See \link[Bernadette]{contact_matrix}.
#'
#' @return A heatmap of a contact matrix for a particular country.
#'
#' @examples
#'
#' \dontrun{
#'
#' cm <- contact_matrix(country = "GRC")
#'
#' plot_cm <- plot_contact_matrix(cm)
#'}
#'
#' @export
plot_contact_matrix <- function(x) {

  levs <- as.factor( colnames(x) )
  levs <- factor(levs, levels = colnames(x))

  plot_data <- x %>%
               as.data.frame() %>%
               tibble::rownames_to_column("indiv_age") %>%
               tidyr::pivot_longer(-c(indiv_age), names_to = "contact_age", values_to = "contact")

  out <- ggplot2::ggplot(plot_data,
                         ggplot2::aes(y    = contact_age,
                                      x    = indiv_age)) +
         ggplot2::geom_tile(ggplot2::aes(fill = contact)) +
         ggplot2::xlim(levs) +
         ggplot2::ylim(levs) +
         ggplot2::xlab("Age of individual") +
         ggplot2::ylab("Age of contact") +
         ggplot2::coord_cartesian(expand = FALSE) +
         ggplot2::scale_fill_continuous(guide = ggplot2::guide_legend(), type ="viridis") +
         ggplot2::guides(fill = ggplot2::guide_colourbar(barwidth = 0.5, title = "Contact rate") ) +
         ggplot2::theme_bw()

 return(out)
}

