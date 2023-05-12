//---- igbm data:								  
int<lower = 1> A;                 // Number of age groups
int<lower = 1> n_obs;             // Length of analysis period
int y_data[n_obs,A];              // Count outcome -  Age-specific mortality counts	
		
int<lower = 1> n_pop;             // Population
real age_dist[A];                 // Age distribution of the general population
vector[A] pop_diag;               // Inverse of population for each age group

int<lower = 1> n_difeq;           // Number of differential equations (S,I,C)

vector[A] L_cm[A];                // Lower triangular matrix, stemming from the Cholesky decomposition of the observed contact matrix
real<lower = 0, upper = 1> age_specific_ifr[n_obs,A];  // Age-specific Infection-fatality rate per age group

real t0;                          // Initial time point (zero)
real ts[n_obs];                   // Time bins
real<lower=0> left_t[n_obs];      // Left time limit
real<lower=0> right_t[n_obs];     // Right time limit
vector<lower = 0>[n_obs] I_D;     // Discretized infection to death distribution.         
row_vector[A] E_deathsByAge_day1; // Age-specific mortality coutns at day 1 of the analysis

//---- Fixed parameters:
real incubation_period;
real infectious_period;  
 
/*
//---- Negative binomial variance formulation: 
0 = variance as a quadratic function of the mean 
1 = variance as a linear function of the mean  
*/
int<lower = 0, upper = 1> likelihood_variance_type;

/*
//---- Prior hyperparameters for volatility parameters:
1 = Half-Normal(prior_mean_volatility, prior_scale_volatility)
2 = Half-Cauchy(prior_mean_volatility, prior_scale_volatility)
3 = Half Student-t(prior_df_volatility, prior_mean_volatility, prior_scale_volatility)
4 = Gamma(prior_shape_volatility, prior_rate_volatility)
5 = Exponential(prior_rate_volatility)
*/
int<lower = 1, upper = 5> prior_dist_volatility;
real<lower=0> prior_mean_volatility;
real<lower=0> prior_scale_volatility;
real<lower=0> prior_df_volatility;
real<lower=0> prior_shape_volatility;
real<lower=0> prior_rate_volatility;

/*
//---- Prior hyperparameters for NegativeBinomial dispersion parameter:
1 = Half-Normal(prior_mean_nb_dispersion, prior_scale_nb_dispersion)
2 = Half-Cauchy(prior_mean_nb_dispersion, prior_scale_nb_dispersion)
3 = Half Student-t(prior_df_nb_dispersion, prior_mean_nb_dispersion, prior_scale_nb_dispersion)
4 = Gamma(prior_shape_nb_dispersion, prior_rate_nb_dispersion)
5 = Exponential(prior_rate_nb_dispersion)
*/
int<lower = 1, upper = 5> prior_dist_nb_dispersion;
real<lower=0> prior_mean_nb_dispersion;
real<lower=0> prior_scale_nb_dispersion;
real<lower=0> prior_df_nb_dispersion;
real<lower=0> prior_shape_nb_dispersion;
real<lower=0> prior_rate_nb_dispersion;

real<lower=0> prior_scale_x0; // Assume a Normal(0, prior_scale_x0) distribution for the age-specific trajectories at t = 0.
real<lower=0> prior_scale_contactmatrix;             
matrix<lower = 0>[1,2] prior_dist_pi;