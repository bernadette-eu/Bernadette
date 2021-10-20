###########################################################################
#
# Setup
#
###########################################################################

#---- Session info:
sessionInfo()

#---- Libraries:

# Install the Bernadette MSCA R library:
if (!require("devtools")) {
  install.packages("devtools")
}

devtools::install_github("bernadette-eu/Bernadette", dependencies = TRUE, build_vignettes = FALSE)

# Load the required libraries:
lib <- c("ggplot2",
         "tidyverse",
         "rvest",
         "vroom",
         "rstan",
         "cmdstanr",
         "bayesplot",
         "gridExtra",
         "mgcv",
         "Bernadette"
)
lapply(lib, require, character.only = TRUE)

#---- Path to .stan file:
stan_file_path  <- ".../Test_Adjoint_v2"

#---- Set the path to the cmdstan-ode-adjoint-v2 version:
cmdstanDirBase <- paste0(Sys.getenv("HOME"),'/.cmdstan/')

# install_cmdstan(dir        = cmdstanDirBase,
#                 release_url="https://github.com/rok-cesnovar/cmdstan/releases/download/adjoint_ODE_v2/cmdstan-ode-adjoint-v2.tar.gz")
#                 check_toolchain = FALSE)

cmdstanVersion <- c("cmdstan-2.27.0", "cmdstan-ode-adjoint-v2")
cmdstanDir     <- file.path(cmdstanDirBase, cmdstanVersion[1])

set_cmdstan_path(cmdstanDir)

###########################################################################
#
# Data import [country population, new daily cases and new daily deaths]
#
###########################################################################
country_pop <- Bernadette::country_population(country = "Greece", year = 2020)

cd <- Bernadette::import_cases_deaths(country    = "Greece",
                                      start_date = "2020-03-02",
                                      end_date   = "2021-03-31")

# Infection-to-onset distribution:
ditd <- Bernadette::discretize_itd(ts_length  = length(cd$Date_range),
                                   gamma_mean = 24.19231,
                                   gamma_cv   = 0.3987261)

###########################################################################
#
# Stan model statement:
#
###########################################################################
compilation_time_start <- Sys.time()

m1 <- cmdstanr::cmdstan_model(paste0(stan_file_path, ".stan"))

compilation_time_end <- Sys.time()
duration_compilation <- compilation_time_end - compilation_time_start

###########################################################################
#
# HMC initialisation:
#
###########################################################################

#---- Initial state of the system - Almost all individuals are susceptible at the start of the epidemic
# We assume that initially there are country_population - 7 susceptible individuals and
# 7 infectious individuals (that have just become infected)
initial_state_raw <- c(country_pop - 7, 7, 0, 0)
left              <- cd$Cases_deaths$Index
right             <- cd$Cases_deaths$Index + 1

#---- Modify data into a form suitable for Stan:
cov_data <- list(n_obs             = length(cd$Date_range),
                 n_pop             = country_pop,
                 n_difeq           = length(initial_state_raw),
                 initial_state_raw = initial_state_raw,
                 y_deaths          = cd$Cases_deaths$New_Deaths,
                 # GBM volatility change-points:
                 sigmaBM_cp1 = cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2020-08-01"],
                 sigmaBM_cp2 = cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2021-01-12"],
                 # ODE solver input:
                 ts          = cd$Cases_deaths$Index,
                 left_t      = left,
                 right_t     = right,
                 # Prior distributions:
                 eta0_sd              = 1,
                 eta1_sd              = 1,
                 gamma_shape          = 204,
                 gamma_scale          = 1428,
                 sigmaBM_sd           = 5,
                 reciprocal_phi_scale = 5,
                 # Infection-to-death distribution:
                 I_D         = ditd,
                 # Predictions - how many weeks into the future:
                 weeks_ahead = 1,
                 # Adjoint ODE solver parameters:
                 rel_tol_forward               = 1e-6,                                # Relative tolerance for forward solve
                 abs_tol_forward               = rep(1e-8,length(initial_state_raw)), # Absolute tolerance vector for each state for forward solve
                 rel_tol_backward              = 1e-6,                                # Relative tolerance for backward solve
                 abs_tol_backward              = rep(1e-5,length(initial_state_raw)), # Absolute tolerance vector for each state for backward solve
                 rel_tol_quadrature            = 1e-6,                                # Relative tolerance for backward quadrature
                 abs_tol_quadrature            = 1e-5,                                # Absolute tolerance for backward quadrature
                 max_num_steps                 = 1e+07,                               # Maximum number of time-steps to take in integrating the ODE solution between output time points for forward and backward solve
                 num_steps_between_checkpoints = 150,                                 # Number of steps between checkpointing forward solution
                 interpolation_polynomial      = 1,                                   # Interpolation polynomial: 1=Hermite= , 2=polynomial
                 solver_forward                = 2,                                   # Solver for forward phase: 1=Adams= , 2=BDF
                 solver_backward               = 1                                    # Solver for backward phase: 1=Adams= , 2=BDF
                 )

#---- Specify parameters to monitor:
parameters <- c("beta0",
                "beta_N",
                "gamma",
                "sigmaBM1",
                "sigmaBM2",
                "sigmaBM3",
                "R_t",
                "E_cases",
                "E_deaths",
                "phiD",
                "log_lik",
                "pred_weekly_deaths",
                "dev")

###########################################################################
#
# Fit and sample from the posterior using Hamiltonian Monte Carlo - NUTS:
#
###########################################################################

parallel::detectCores()

#---- MCMC options:
nChains <- 2
nBurn   <- 2000 ## Number of warm-up samples per chain after thinning
nPost   <- 5000 ## Number of post-warm-up samples per chain after thinning
nThin   <- 1
nIter   <- nPost * nThin
nBurnin <- nBurn * nThin

#---- Stan options:
rstan_options(auto_write = TRUE)
options(mc.cores = nChains)

#---- Set initial values:
set.seed(1)

ini_1 <- function(){
  list(eta0            = runif(1, -2.4, -2.2),
       eta             = rep(runif(1, -2, -1.4), length(cd$Date_range)),
       gamma           = runif(1, 0.14, 0.15),
       sigmaBM1        = runif(1, 0.1, 4),
       sigmaBM2        = runif(1, 0.1, 4),
       sigmaBM3        = runif(1, 0.1, 4),
       reciprocal_phiD = runif(1, 0.5, 1.5)
  )
}# End function

#---- Test execution:
test <- m1$sample(data            = cov_data,
                  init            = ini_1,
                  chains          = 1,
                  parallel_chains = 1,
                  seed            = 1,
                  refresh         = 1,
                  iter_warmup     = 2,
                  iter_sampling   = 2,
                  max_treedepth   = 19,
                  adapt_delta     = 0.99,
                  show_messages   = FALSE
                  )

compilation_time_start <- Sys.time()
nuts_fit_1 <- m1$sample(data            = cov_data,
                        init            = ini_1,
                        chains          = nChains,
                        parallel_chains = nChains,
                        seed            = 1,
                        refresh         = 500,
                        iter_warmup     = nBurnin,
                        iter_sampling   = nIter,
                        thin            = nThin,
                        max_treedepth   = 19,
                        adapt_delta     = 0.99,
                        show_messages   = FALSE)
time.end_nuts1 <- Sys.time()
duration_nuts1 <- time.end_nuts1 - compilation_time_start

print( get_elapsed_time(nuts_fit_1) )

###########################################################################
#
# Store HMC output and MCMC summaries
#
###########################################################################
stanfit <- rstan::read_stan_csv(nuts_fit_1$output_files())

save.image(file = store_model_out )

load(file = store_model_out)

###########################################################################
#
# Posterior summaries
#
###########################################################################
nuts_fit_1_summary <- summary(stanfit,
                              pars = c("lp__",
                                       # Intermediate betas:
                                       "beta_N[27]",  # "2020-03-28
                                       "beta_N[69]",  # "2020-05-09"
                                       "beta_N[100]", # "2020-06-09"
                                       "beta_N[153]", # "2020-08-01"
                                       "beta_N[315]", # "2021-01-10"
                                       "beta_N[346]", # "2021-02-10"
                                       "beta_N[359]", # "2021-02-23"
                                       "beta_N[390]", # "2021-03-26"
                                       "gamma",
                                       "sigmaBM1",
                                       "sigmaBM2",
                                       "sigmaBM3",
                                       "phiD"))$summary

options(scipen = 999)
print(nuts_fit_1_summary, scientific = FALSE, digits = 2)
