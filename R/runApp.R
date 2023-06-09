#' @export
runApp <- function() {

  options(shiny.maxRequestSize = 80*1024^2)

  appDir <- system.file("shiny", "BernadetteApp", package = "Bernadette")

  if (appDir == "") {
    stop("Could not find example directory. Try re-installing `Bernadette`.", call. = FALSE)
  }

  shiny::runApp(appDir, display.mode = "normal")

}
