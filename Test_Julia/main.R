###########################################################################
#
# Setup
#
###########################################################################

#---- Libraries:
library("JuliaConnectoR")

main_path <- ".../"

julia_module_path  <- paste0(main_path,"/src/", "test_module.jl")

path_data          <- paste0(main_path, "data/")
store_cd_data      <- paste0(path_data, "cd_12months", ".RData")
store_all_data     <- paste0(path_data, "All_data", ".RData")

julia_system_path <- ".../Julia-1.7.0/bin"

#---- Define the system path to Julia:
Sys.setenv(JULIA_BINDIR = julia_system_path)

#---- Initiate Julia and start the package manager:
Pkg    <- juliaImport("Pkg")
Turing <- juliaImport("Turing")

#---- Session info: change locale to English for correct axis
#     label display in the graphs:
sessionInfo()

###########################################################################
#
# Data import
#
###########################################################################
load(file = store_cd_data)
load(file = store_all_data)

###########################################################################
#
# Import Julia module from the .jl source code
#
###########################################################################
time_start_module <- Sys.time()
SIR_mcmc_module   <- juliaImport(juliaCall("include", julia_module_path))
time_end_module   <- Sys.time()
duration_module   <- time_end_module - time_start_module

print( duration_module )

###########################################################################
#
# HMC initialisation:
#
###########################################################################

#---- Initial state of the system - Almost all individuals are susceptible at the start of the epidemic
initial_states <- c(country_pop - 7, 7, 0, 0)
left           <- cd$Cases_deaths$Index
right          <- left + 1
right          <- as.integer(right)

###########################################################################
#
# HMC implementation:
#
###########################################################################

#---- Create a new scope, and declare variables in this scope:
juliaLet('Dict("y_deaths" => y_deaths,
         "n_obs"   => n_obs,
         "n_pop"   => n_pop,
         "n_difeq" => n_difeq,
         "y_init"  => y_init,
         "ts"      => ts,
         "left_t"  => left_t,
         "right_t" => right_t,
         "eta0_sd" => eta0_sd,
         "eta1_sd" => eta1_sd,
         "gamma_shape" => gamma_shape,
         "gamma_scale" => gamma_scale,
         "sigmaBM_sd"  => sigmaBM_sd,
         "reciprocal_phi_scale" => reciprocal_phi_scale,
         "sigmaBM_cp1" => sigmaBM_cp1,
         "sigmaBM_cp2" => sigmaBM_cp2,
         "I_D_rev"     => I_D_rev
         )',
         y_deaths    = cd$Cases_deaths$New_Deaths,
         n_obs       = length(cd$Date_range),
         n_pop       = country_pop,
         n_difeq     = length(initial_states),
         y_init      = initial_states,
         ts          = cd$Cases_deaths$Index,
         left_t      = left,
         right_t     = right,
         eta0_sd     = 1L,
         eta1_sd     = 1L,
         gamma_shape = 204L,
         gamma_scale = 1428L,
         sigmaBM_sd  = 5L,
         reciprocal_phi_scale = 5L,
         sigmaBM_cp1 = cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2020-08-01"],
         sigmaBM_cp2 = cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2021-01-12"],
         I_D_rev     = I_D_rev
)

#---- Execute NUTS:
model_sir <- SIR_mcmc_module$bayes_sir(cd$Cases_deaths$New_Deaths,
                                       length(cd$Date_range),
                                       country_pop,
                                       length(initial_states),
                                       initial_states,
                                       cd$Cases_deaths$Index,
                                       left,
                                       right,
                                       1L,
                                       1L,
                                       204L,
                                       1428L,
                                       5L,
                                       5L,
                                       cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2020-08-01"],
                                       cd$Cases_deaths$Index[cd$Cases_deaths$Date == "2021-01-12"],
                                       I_D_rev)

nuts_fit_1 <- Turing$sample(model_sir,
                            Turing$NUTS(0.7),
                            700)
