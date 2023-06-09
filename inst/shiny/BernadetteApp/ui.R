# --- Define User Interface
library(shiny)

#---- Set system locale to English:
Sys.setlocale("LC_ALL", "English")

#---- Define UI
ui <- fluidPage(

  #---- App title
  #titlePanel("Infectious disease modeling with Bernadette"),
  titlePanel("INFECTIOUS DISEASE MODELING"),

  #---- Sidebar
  sidebarLayout(

    sidebarPanel(

      h2("Uploading Files"),

      # Input: Select a file ----
      fileInput(inputId  = "upload",
                label    = "Choose RData File",
                multiple = FALSE,
                accept   = c(".RData") ),

      p("The file must contain three objects from the workflow:"),
      p("1. 'age_specific_mortality_counts', the data.frame containing the age-specific time series of new mortality counts"),
      p("2. 'aggr_age', the age distribution table, see aggregate_age_distribution()"),
      p("3. 'igbm_fit', the output of stan_igbm()."),
      br(),
      # Text: Installation guidelines ----
      h2("Installation"),
      p("Bernadette is available on CRAN, so you can install it in the usual way from your R console:"),
      code('install.packages("Bernadette")'),
      br(),
      br(),
      p("The Bernadette package performs infectious disease modeling using the methods described in Bouranis, L.,
      Demiris, N., Kalogeropoulos, K., and Ntzoufras, I. (2022) <arXiv:2211.15229>."),
      br(),
      # Text: Funding ----
      h2("Funding"),
      p("European Union's Horizon 2020 research and innovation programme under the Marie Sklodowska-Curie grant agreement No 101027218.")
    ),
    #---- Main panel with tabs
    mainPanel(
      h1("Estimation of key epidemiological quantities"),
      tabsetPanel(
        id = "tabs",
        tabPanel(
          title = "Infections per group",
          plotOutput(outputId = "plot_age_infections")
        ),
        tabPanel(
          title = "Total Infections",
          plotOutput(outputId = "plot_total_infections")
        ),
        tabPanel(
          title = "Deaths per group",
          plotOutput(outputId = "plot_age_deaths")
        ),
        tabPanel(
          title = "Total deaths",
          plotOutput(outputId = "plot_total_deaths")
        ),
        tabPanel(
          title = "Contact matrix",
          plotOutput(outputId = "plot_cm")
        ),
        tabPanel(
          title = "Transmission rate",
          plotOutput(outputId = "plot_transmrate")
        ),
        tabPanel(
          title = "Effective reproduction number",
          plotOutput(outputId = "plot_rt")
        )
      )
    )
  )
)
