expect_rows <- function(object) {
  # 1. Capture object and label
  act <- testthat::quasi_label(rlang::enquo(object), arg = "object")

  # 2. Call expect()
  expect(
    nrow(act$val) == 16,
    "The object does not contain 16 rows"
  )

  # 3. Invisibly return the value
  invisible(act$val)
}

expect_agrr_rows <- function(object, lookup_table) {
  # 1. Capture object and label
  act <- testthat::quasi_label(rlang::enquo(object), arg = "object")

  # 2. Call expect()
  expect(
    nrow(act$val) == length(unique(lookup_table$Mapping)),
    paste0("The object does not contain ", length(unique(lookup_table$Mapping)), " rows")
  )

  # 3. Invisibly return the value
  invisible(act$val)
}

check_stanfit <- function(x) {
  if (is.list(x)) {
    if (!all(c("par", "value") %in% names(x)))
      stop("Invalid object produced please report bug")
  } else {
    stopifnot(is(x, "stanfit"))
    if (x@mode != 0)
      stop("Invalid stanfit object produced please report bug")
  }
  return(TRUE)
}

laus <- function(x) {
  r <-
    tryCatch(
      withCallingHandlers(
        {
          error_text <- "No error."
          list(value = hurz(x), error_text = error_text)
        },
        warning = function(e) {
          error_text <<- trimws(paste0("WARNING: ", e))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        return(list(value = NA, error_text = trimws(paste0("ERROR: ", e))))
      },
      finally = {
      }
    )

  return(r)
}

