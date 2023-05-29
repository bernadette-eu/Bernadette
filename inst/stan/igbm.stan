functions {
//---- Data transformation functions:
matrix to_triangular(vector x, int K) {

	matrix[K, K] y = rep_matrix(0.0, K, K); //Declare a matrix of zeros to avoid NaNs in the upper triangular part.
	int pos = 1;

	for (col in 1:K) {
		for (row in col:K) {
		  y[row, col] = x[pos];
		  pos += 1;
		}
	}

	return y;
}// End function

real[] rep_each(real[] x, int K) {
	int N = size(x);
	real y[N  *  K];
	int pos = 1;

	for (n in 1:N) {
	  for (k in 1:K) {
		y[pos] = x[n];
		pos += 1;
	  }
	}
	return y;
}// End function

real[] to_vector_rowwise(matrix x) {

  real res[num_elements(x)];
  int n;
  int m;

  n = rows(x);
  m = cols(x);

  for (i in 1:n) for (j in 1:m) res[(i - 1) * m + j] = x[i, j];

  return res;
}// End function

real[] to_vector_colwise(matrix x) {

  real res[num_elements(x)];
  int n;
  int m;

  n = rows(x);
  m = cols(x);

  for (i in 1:n) for (j in 1:m) res[n * (j - 1) + i] = x[i, j];

  return res;
}// End function

//---- Non-linear Ordinary Differential Equation (ODE) system (SEEIIR):
real[] ODE_states(real time,     // Time
				  real[] y,      // System state {susceptible,infected,recovered}
				  real[] theta,  // Parameters
				  real[] x_r,    // Real-type data
				  int[] x_i      // Integer-type data
				  ){

  int A       = x_i[1];    // Number of age groups
  int n_obs   = x_i[2];    // Length of the time series
  int n_difeq = x_i[3];    // Number of differential equations in the system

  real dy_dt[A * n_difeq]; // SEEIIR (ignoring R) then C
  real f_inf[A];           // Force of infection
  real init[2 * A];        // Initial values at (S, E1) compartmens

  real age_dist[A]    = x_r[(2 * n_obs + 1):(2 * n_obs + A)];  // Population per age group

  // Estimated parameters:
  real contact[A * A] = theta[1:(A * A)]; // Sampled contact matrix in vectorized format.
										  // First A values correspond to number of contact between age band 1 and other bands, etc.
  real gamma          = theta[A * A + 1]; // Recovery rate
  real tau            = theta[A * A + 2]; // Incubation rate

  real pi             = theta[A * A + 3];                 // Number of cases at t0
  real beta[A]        = theta[(A * A + 4):(A*A + A + 3)]; // Effective contact rate

  // Compartments:
  for (i in 1:A){

	init[i]     = age_dist[i] * (1-pi); // Initial states - Susceptibles compartment
	init[A + i] = age_dist[i] * pi;     // Initial states - Exposed 1 compartment

	// Force of infection by age group:
	f_inf[i] = sum( to_vector(beta) .* ( to_vector( y[(3*A+1):(4*A)] ) +
										 to_vector( y[(4*A+1):(5*A)] )
									    ) ./ to_vector(age_dist) .* to_vector(contact[(A*(i-1)+1):(i*A)]) );


	// S: susceptible
	dy_dt[i] = - f_inf[i] * ( y[i] + init[i] );

	// E1: incubating (not yet infectious)
	dy_dt[A + i] = f_inf[i] * ( y[i] + init[i] ) - tau  *  ( y[A + i] + init[A + i] );

	// E2: incubating (not yet infectious)
	dy_dt[2 * A + i] = tau * ( ( y[A + i] + init[A + i] ) - y[2 * A + i]  );

	// I1: infectious
	dy_dt[3 * A + i] = tau * y[2 * A + i] - gamma * y[3 * A + i];

	// I2: infectious
	dy_dt[4 * A + i] = gamma * ( y[3 * A + i] - gamma * y[4 * A + i] );

	// C: cumulative number of infections by date of disease onset
	dy_dt[(n_difeq-1) * A + i] = tau * y[2 * A + i];

   }// End for

  return dy_dt;
}// End SEIR function

//---- ODE system integration using the trapezoidal rule:
real[,] integrate_ode_trapezoidal(real[] y_initial,
								  real initial_time,
								  real[] times,  // Vector of time indexes
								  real[] theta,  // Parameters
								  real[] x_r,    // Real-type data
								  int[] x_i      // Integer-type data
								  )
{

  real h;
  vector[size(y_initial)] dy_dt_initial_time;
  vector[size(y_initial)] dy_dt_t;
  vector[size(y_initial)] k;

  real y_approx[size(times),size(y_initial)];

  int A       = x_i[1];  // Number of age groups
  int n_obs   = x_i[2];
  real theta_ODE[A*A + A + 3];

  real left_t[n_obs]  = x_r[1:n_obs];              // Left and right time bounds for the calculation of the time-dependent incidence rate
  real right_t[n_obs] = x_r[(n_obs+1):(2 * n_obs)];// Left and right time bounds for the calculation of the time-dependent incidence rat
  real beta_N_temp[A*n_obs] = theta[(A*A + 3):(A*n_obs + A*A + 2)];

  // Define the parameter vector that enters the ode_states():
  theta_ODE[1:(A * A)] = theta[1:(A * A)];         // Vectorized contact matrix
  theta_ODE[A * A + 1] = theta[A * A + 1];         // gamma = Recovery rate
  theta_ODE[A * A + 2] = theta[A*n_obs + A*A + 4]; // tau   = Incubation rate
  theta_ODE[A * A + 3] = theta[A*n_obs + A*A + 3]; // pi

  for (t in 0:(size(times)-1)) {
	if(t == 0){

	   for (j in 1:A) theta_ODE[A * A + 3 + j] = theta[A * A + 2]; // beta0

	   h = times[1] - initial_time;
	   dy_dt_initial_time = to_vector(ODE_states(initial_time, y_initial, theta_ODE, x_r, x_i));
	   k = h*dy_dt_initial_time;

	   y_approx[t+1,] = to_array_1d(
						  to_vector(y_initial) +
						  h*(dy_dt_initial_time +
							 to_vector(ODE_states(times[1],
												  to_array_1d(to_vector(y_initial) + k),
												  theta_ODE, x_r, x_i)))/2);

	} else {
		h = (times[t+1] - times[t]);

		for (j in 1:A){
			 // Assign the effective contact rate parameter at the last time point
			if (t == (size(times) - 1) ) theta_ODE[A * A + 3 + j] = beta_N_temp[n_obs * (j - 1) +  t + 1];
			else if(t >= left_t[t] && t <= right_t[t]) theta_ODE[A * A + 3 + j] = beta_N_temp[n_obs * (j - 1) +  t];
		}// End for

		dy_dt_t = to_vector(ODE_states(times[t], y_approx[t], theta_ODE, x_r, x_i));

		k = h*dy_dt_t;

		y_approx[t+1,] = to_array_1d(
							to_vector(y_approx[t,]) +
							h*(dy_dt_t + to_vector(ODE_states(times[t+1],
															  to_array_1d(to_vector(y_approx[t,]) + k),
															  theta_ODE, x_r, x_i)
															  )) /2 );

	}// End if
  }// End for

  return y_approx;

} // End trapezoidal rule function
}

data {
//#include /data/data_igbm.stan
//---- igbm data:
int A;                 // Number of age groups
int n_obs;             // Length of analysis period
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
}

transformed data {
vector<lower = 0>[n_obs] I_D_rev;                        // Reversed discretized infection-to-death distribution

int x_i[3];
real x_r[2 * n_obs + A];
real<lower = 0> gamma;
real<lower = 0> tau;

real init[A * n_difeq] = rep_array(0.0, A * n_difeq);    // Initial conditions for the (S,E,I,C) compartments

vector[A] ones_vector_A = rep_vector(1.0, A);

vector[(A * (A + 1)) / 2] L_vector = rep_vector(0, (A * (A + 1)) / 2);

//---- Infection-fatality rate per age group
for( t in 1:n_obs ) I_D_rev[t] = I_D[n_obs - t + 1];

x_i[1] = A;
x_i[2] = n_obs;
x_i[3] = n_difeq;

x_r[1:n_obs]                         = left_t;
x_r[(n_obs+1):(2 * n_obs)]           = right_t;
x_r[(2 * n_obs + 1):(2 * n_obs + A)] = age_dist;

tau    = 2.0/incubation_period;
gamma  = 2.0/infectious_period;

}

parameters {
real x0;                          // Initial transmission rate
real x_noise[n_obs*A];
real<lower = 0, upper = 1> pi;    // Number of population infections at t0
real<lower = 0> volatilities[A];  // Standard deviation of GBM
real<lower = 0> phiD;             // Likelihood variance parameter
vector[(A * (A + 1)) / 2] L_raw;  // Vectorized version of the L matrix. Used to apply a NCP to calculate the sampled contact matrix .
}

transformed parameters{
matrix[n_obs, A] x_trajectory;
real<lower = 0> beta0;                       // Initial transmission rate

matrix<lower = 0>[n_obs, A] beta_trajectory; // Daily Effective contact rate, beta_trajectory = exp(x_trajectory)
real<lower = 0> beta_N[n_obs*A];             // Daily Effective contact rate

real theta[A*A + A*n_obs + 4];               // Vector of ODE parameters
real state_solutions[n_obs, A * n_difeq];    // Solution from the ODE solver
matrix[n_obs, A] comp_C;			         // Store the calculated values for the dummy ODE compartment

matrix<lower = 0>[n_obs, A] E_casesByAge;    // Expected infections per group
matrix<lower = 0>[n_obs, A] E_deathsByAge;   // Expected deaths per age group

matrix[A, A] cm_sym;
matrix[A, A] cm_sample;

//---- Transformed parameters for the contact matrix (Non-central parameterisation):
matrix[A, A] L_raw_mat         = to_triangular(L_raw, A);
matrix[A, A] L                 = to_triangular(L_vector, A);
matrix[n_obs, A]   x_noise_mat = to_matrix(x_noise, n_obs, A);

for(col in 1:A) for(row in col:A) L[row,col] = L_cm[row,col] + (prior_scale_contactmatrix * L_cm[row,col]) *  L_raw_mat[row,col];

cm_sym    = tcrossprod(L);
cm_sample = diag_pre_multiply(pop_diag, cm_sym);

//---- Transformed parameters for the GBM (Non-central parameterisation):
for (j in 1:A) x_trajectory[1,j] = x0 + volatilities[j] * x_noise_mat[1,j];

for (t in 2:n_obs) for (j in 1:A) x_trajectory[t,j] = x_trajectory[t-1,j] + volatilities[j] * x_noise_mat[t,j]; // Implies x_trajectory[i,j] ~ normal(x_trajectory[i-1,j], volatilities[j]);

beta0           = exp(x0);
beta_trajectory = exp(x_trajectory);
beta_N          = to_vector_colwise(beta_trajectory);

//---- Change of format for integrate_ode_euler/ integrate_ode_rk45/ integrate_ode_bdf:
theta[1:(A * A)]                     = to_vector_rowwise(cm_sample);
theta[A * A + 1]                     = gamma;
theta[A * A + 2]                     = beta0;
theta[(A*A + 3):(A*A + A*n_obs + 2)] = beta_N;
theta[A*n_obs + A*A + 3]             = pi;
theta[A*n_obs + A*A + 4]             = tau;

//---- Solution to the ODE system:
state_solutions = integrate_ode_trapezoidal(init,   // initial states
										    t0,     // initial_time,
										    ts,     // real times
										    theta,  // parameters
										    x_r,    // real data
										    x_i     // integer data
										    );

//---- Calculate new daily Expected cases and Expected deaths for each age group:
for (t in 1:n_obs) {

	if(t == 1) E_deathsByAge[t,] = E_deathsByAge_day1;

	for (j in 1:A){

		//--- Format ODE results
		comp_C[t,j] = state_solutions[t,(n_difeq-1) * A + j]  *  n_pop;

		//--- Alternative option:
		E_casesByAge[t,j] = comp_C[t,j] - (t == 1 ? 0 : ( comp_C[t,j] > comp_C[t-1,j] ? comp_C[t-1,j] : 0) );

		//--- Expected deaths by calendar day and age group:
		if(t != 1) E_deathsByAge[t,j] =  age_specific_ifr[t,j] * dot_product(head(E_casesByAge[,j], t-1), tail(I_D_rev, t-1));
	}// End for
}//End for
}

model {

//---- Prior distributions:
pi           ~ beta(prior_dist_pi[1,1], prior_dist_pi[1,2]);
x0           ~ normal(0, prior_scale_x0);
x_noise      ~ std_normal();
L_raw        ~ std_normal();

if (prior_dist_volatility == 1)         volatilities ~ normal(prior_mean_volatility, prior_scale_volatility); // Half-Normal
else if (prior_dist_volatility == 2)    volatilities ~ cauchy(prior_mean_volatility, prior_scale_volatility); // Half-Cauchy
else if (prior_dist_volatility == 3)    volatilities ~ student_t(prior_df_volatility, prior_mean_volatility, prior_scale_volatility); // Half Student-t
else if (prior_dist_volatility == 4)    volatilities ~ gamma(prior_shape_volatility, prior_rate_volatility); // Gamma
else if (prior_dist_volatility == 5)    volatilities ~ exponential(prior_rate_volatility);                   // Exponential

if (prior_dist_nb_dispersion == 1)      phiD ~ normal(prior_mean_nb_dispersion, prior_scale_nb_dispersion); // Half-Normal
else if (prior_dist_nb_dispersion == 2) phiD ~ cauchy(prior_mean_nb_dispersion, prior_scale_nb_dispersion); // Half-Cauchy
else if (prior_dist_nb_dispersion == 3) phiD ~ student_t(prior_df_nb_dispersion, prior_mean_nb_dispersion, prior_scale_nb_dispersion); // Half Student-t
else if (prior_dist_nb_dispersion == 4) phiD ~ gamma(prior_shape_nb_dispersion, prior_rate_nb_dispersion); // Gamma
else if (prior_dist_nb_dispersion == 5) phiD ~ exponential(prior_rate_nb_dispersion);                      // Exponential


//---- Likelihood:
	for(i in 1:n_obs) {
		for (j in 1:A) {
			if (likelihood_variance_type == 0)      target += neg_binomial_2_lpmf( y_data[i,j] | E_deathsByAge[i,j], phiD);
			else if (likelihood_variance_type == 1) target += neg_binomial_2_lpmf( y_data[i,j] | E_deathsByAge[i,j], E_deathsByAge[i,j]/phiD);
		}// End for
	}// End for
}

generated quantities {
vector[n_obs] E_cases;         // Expected infections <lower = 0>
vector[n_obs] E_deaths;        // Expected deaths <lower = 0>
matrix[n_obs, A] Susceptibles; // Counts of susceptibles at time t, for age group a = 1,..,A.
							   // To be used for the calculation of the time-varying Effective Reproduction Number.
matrix[n_obs,A] log_like_age;
vector[n_obs] log_lik;         // Log-likelihood vector for use by the loo package.

real deviance;                 // Deviance

//---- Total expected number of new infections per day:
E_cases = E_casesByAge * ones_vector_A;

//---- Total expected number of new deaths per day:
E_deaths = E_deathsByAge * ones_vector_A;

//---- Counts of age-specific susceptibles & log-likelihood:
for (t in 1:n_obs) {

	for (j in 1:A) {
		Susceptibles[t,j] = ( state_solutions[t,j] + (age_dist[j]  * (1-pi)) )* n_pop ;

		if (likelihood_variance_type == 0)      log_like_age[t,j] = neg_binomial_2_lpmf(y_data[t,j] | E_deathsByAge[t,j], phiD);
		else if (likelihood_variance_type == 1) log_like_age[t,j] = neg_binomial_2_lpmf(y_data[t,j] | E_deathsByAge[t,j], E_deathsByAge[t,j]/phiD);

	}// End for

	log_lik[t] = sum(log_like_age[t,]);
}// End for

//---- Deviance:
deviance = (-2)  *  sum(log_lik);
}
