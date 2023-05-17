#' Contact matrix heatmap
#'
#' @param x data.frame;
#' a contact matrix.  See \link[Bernadette]{contact_matrix}.
#'
#' @return A ggplot object that can be further customized using the
#'   \pkg{ggplot2} package.
#'
#' @examples
#' # Import the projected contact matrix for Greece:
#' conmat <- contact_matrix(country = "GRC")
#'
#' plot_contact_matrix(conmat)
#'
#' @export
#'
plot_contact_matrix <- function(x) {

  levs <- as.factor( colnames(x) )
  levs <- factor(levs, levels = colnames(x))
  x$indiv_age <- rownames(x)

  plot_data <- stats::reshape(x,
                              idvar     = "indiv_age",
                              timevar   = "contact_age",
                              v.names   = "contact",
                              varying   = list(names(x)[1:(ncol(x)-1)]),
                              times     = colnames(x)[-ncol(x)],
                              direction = "long")
  rownames(plot_data) <- NULL

  plot_data <- plot_data[order(plot_data$indiv_age, plot_data$contact_age), ]

  out <- ggplot2::ggplot(plot_data,
                         ggplot2::aes(y    = contact_age,
                                      x    = indiv_age)) +
         ggplot2::geom_tile(ggplot2::aes(fill = contact)) +
         ggplot2::xlim(levs) +
         ggplot2::ylim(levs) +
         ggplot2::labs(x = "Age of individual",
                       y = "Age of contact") +
         ggplot2::coord_cartesian(expand = FALSE) +
         ggplot2::scale_fill_continuous(guide = ggplot2::guide_legend(), type ="viridis") +
         ggplot2::guides(fill = ggplot2::guide_colourbar(barwidth = 0.5, title = "Contact rate") ) +
         ggplot2::theme_bw()

 return(out)
}

