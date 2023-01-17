test_that("Function throws an error if all parameters are set to NULL", {
  expect_error(
    itd_distribution(100,
                    gamma_mean = NULL,
                    gamma_cv   = NULL,
                    gamma_shape= NULL,
                    gamma_rate = NULL)
  )
})

time_points <- 1:100

# Case: SEIR with sigma != gamma:
test1 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 4,
                          latent_stages           = 2,
                          infectious_stages       = 2,
                          erlang_model            = FALSE)

# Case: SEIR with sigma == gamma:
test2 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 3,
                          latent_stages           = 2,
                          infectious_stages       = 2,
                          erlang_model            = FALSE)

# Case: SIR:
test3 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 3,
                          latent_stages           = 0,
                          infectious_stages       = 1,
                          erlang_model            = TRUE)

# Case: SI_2R. m = 0, n = 2:
test4 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 3,
                          latent_stages           = 0,
                          infectious_stages       = 2,
                          erlang_model            = TRUE)

# Case: SE_mI_nR with m >= 1 and m*sigma == n*gamma:
test5 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 3,
                          latent_stages           = 2,
                          infectious_stages       = 2,
                          erlang_model            = TRUE)

# Case: SE_mI_nR with m >= 1 and m*sigma != n*gamma:
test6 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 4,
                          latent_stages           = 2,
                          infectious_stages       = 2,
                          erlang_model            = TRUE)

# Case: SE_mI_nR with m = 1, n = 1 and m*sigma != n*gamma:
# Check that 3.15 of Champredon (2018) is numerically identical to 3.17 for m = n = 1.
test7 <- gti_distribution(ts_length               = length(time_points),
                          latency_duration        = 3,
                          infectiousness_duration = 4,
                          latent_stages           = 1,
                          infectious_stages       = 1,
                          erlang_model            = TRUE)

# Plots of g(t) in time according to different tests:
plot(time_points, test1, xlab = "Time", type = "l") # NOT OK
plot(time_points, test2, xlab = "Time", type = "l") # Reasonable output
plot(time_points, test3, xlab = "Time", type = "l") # Reasonable output
plot(time_points, test4, xlab = "Time", type = "l") # Reasonable output
plot(time_points, test5, xlab = "Time", type = "l") # Reasonable output
plot(time_points, test6, xlab = "Time", type = "l") # Reasonable output
plot(time_points, test7, xlab = "Time", type = "l") # Reasonable output

