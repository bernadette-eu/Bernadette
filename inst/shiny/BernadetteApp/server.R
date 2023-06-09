# Define server logic ----

server <- function(input, output) {

  observeEvent(input$upload,
    {
    if ( is.null(input$upload)) return(NULL)

    inFile <- isolate({input$upload})
    file   <- inFile$datapath

    load(file, envir = .GlobalEnv)

    #---- Visualize the posterior distribution of the infection counts:
    post_inf_summary <- posterior_infections(object = igbm_fit,
                                             y_data = age_specific_mortality_counts)

    output$plot_age_infections <- renderPlot({
      p <- plot_posterior_infections(post_inf_summary, type = "age-specific")
      print(p)
    })

    output$plot_total_infections <- renderPlot({
      p <- plot_posterior_infections(post_inf_summary, type = "aggregated")
      print(p)
      })

    #---- Visualize the posterior distribution of the mortality counts:
    post_mortality_summary <- posterior_mortality(object = igbm_fit,
                                                  y_data = age_specific_mortality_counts)

    output$plot_age_deaths   <- renderPlot({
      p <- plot_posterior_mortality(post_mortality_summary, type = "age-specific")
      print(p)
    })

    output$plot_total_deaths <- renderPlot({
      p <- plot_posterior_mortality(post_mortality_summary, type = "aggregated")
      print(p)
    })

    # Visualise the posterior distribution of the age-specific transmission rate:
    post_transmrate_summary <- posterior_transmrate(object = igbm_fit,
                                                    y_data = age_specific_mortality_counts)

    output$plot_transmrate  <- renderPlot({
      p <- plot_posterior_transmrate(post_transmrate_summary)
      print(p)
    })

    #---- Plot the posterior contact matrix:
    output$plot_cm <- renderPlot({
      p <- plot_posterior_cm(igbm_fit, y_data = age_specific_mortality_counts)
      print(p)
    })

    #---- Visualise the posterior distribution of the effective reproduction number:
    post_rt_summary <- posterior_rt(object                      = igbm_fit,
                                    y_data                      = age_specific_mortality_counts,
                                    age_distribution_population = aggr_age,
                                    infectious_period           = 4)
    output$plot_rt <- renderPlot({
      p <- plot_posterior_rt(post_rt_summary)
      print(p)
    })
  })
}
