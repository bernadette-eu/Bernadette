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

matrix repeat_matrix(matrix input, int K) {
  int N = rows(input);
  int M = cols(input);
  matrix[N * K, M] repmat; // stack N*M matrix K times
  int pos = 1;

	for (n in 1:N) {
	  for (k in 1:K) {
      repmat[pos,] = to_row_vector(input[n,]);
      pos += 1;
	  }
	}
  return repmat;
}

matrix repeat_rv_to_matrix(row_vector input, int K) {
  int M = num_elements(input);
  matrix[K, M] repmat;
  int pos = 1;

  for (k in 1:K) {
    repmat[pos,] = input;
    pos += 1;
  }
  return repmat;
}

array[] real rep_each(array[] real x, int K) {
	int N = size(x);
	array[N  *  K] real y;
	int pos = 1;

	for (n in 1:N) {
	  for (k in 1:K) {
		y[pos] = x[n];
		pos += 1;
	  }
	}
	return y;
}// End function

array[] real to_vector_rowwise(matrix x) {

  array[num_elements(x)] real res;
  int n;
  int m;

  n = rows(x);
  m = cols(x);

  for (i in 1:n) for (j in 1:m) res[(i - 1) * m + j] = x[i, j];

  return res;
}// End function

array[] real to_vector_colwise(matrix x) {

  array[num_elements(x)] real res;
  int n;
  int m;

  n = rows(x);
  m = cols(x);

  for (i in 1:n) for (j in 1:m) res[n * (j - 1) + i] = x[i, j];

  return res;
}// End function

//---- Non-linear Ordinary Differential Equation (ODE) system (SEEIIR):
array[] real ODE_states(real time,     // Time
				  array[] real y,      // System state {susceptible,infected,recovered}
				  array[] real theta,  // Parameters
				  array[] real x_r,    // Real-type data
				  array[] int x_i      // Integer-type data
				  ){

  int A       = x_i[1];    // Number of age groups
  int n_obs   = x_i[2];    // Length of the time series
  int n_difeq = x_i[3];    // Number of differential equations in the system

  array[A * n_difeq] real dy_dt; // SEEIIR (ignoring R) then C
  array[A] real f_inf;           // Force of infection
  array[2 * A] real init;        // Initial values at (S, E1) compartmens

  array[A] real age_dist    = x_r[(2 * n_obs + 1):(2 * n_obs + A)];  // Population per age group

  // Estimated parameters:
  array[A * A] real contact = theta[1:(A * A)]; // Sampled contact matrix in vectorized format.
										  // First A values correspond to number of contact between age band 1 and other bands, etc.
  real gamma          = theta[A * A + 1]; // Recovery rate
  real tau            = theta[A * A + 2]; // Incubation rate

  real pi             = theta[A * A + 3];                 // Number of cases at t0
  array[A] real beta        = theta[(A * A + 4):(A*A + A + 3)]; // Effective contact rate

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
array[,] real integrate_ode_trapezoidal(array[] real y_initial,
								  real initial_time,
								  array[] real times,  // Vector of time indexes
								  array[] real theta,  // Parameters
								  array[] real x_r,    // Real-type data
								  array[] int x_i      // Integer-type data
								  )
{

  real h;
  vector[size(y_initial)] dy_dt_initial_time;
  vector[size(y_initial)] dy_dt_t;
  vector[size(y_initial)] k;

  array[size(times),size(y_initial)] real y_approx;

  int A       = x_i[1];  // Number of age groups
  int n_obs   = x_i[2];
  array[A*A + A + 3] real theta_ODE;

  array[n_obs] real left_t  = x_r[1:n_obs];              // Left and right time bounds for the calculation of the time-dependent incidence rate
  array[n_obs] real right_t = x_r[(n_obs+1):(2 * n_obs)];// Left and right time bounds for the calculation of the time-dependent incidence rat
  array[A*n_obs] real beta_N_temp = theta[(A*A + 3):(A*n_obs + A*A + 2)];

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
//---- igbm data:
int A;                             // Number of age groups
int n_obs;                        // Length of analysis period
array [n_obs,A]int y_data;              // Count outcome -  Age-specific mortality counts
int<lower = 1> n_pop;             // Population
int<lower = 1, upper = 7> ecr_changes;
int n_changes;
int n_remainder;
int L_raw_length;

array[A] real age_dist;                 // Age distribution of the general population
vector[A] pop_diag;               // Inverse of population for each age group
int<lower = 1> n_difeq;           // Number of differential equations (S,I,C)

array[A] vector[A] L_cm;                // Lower triangular matrix, stemming from the Cholesky decomposition of the observed contact matrix
array[n_obs,A] real<lower = 0, upper = 1> age_specific_ifr;  // Age-specific Infection-fatality rate per age group

real t0;                          // Initial time point (zero)
array[n_obs] real ts;                   // Time bins
array[n_obs] real<lower=0> left_t;      // Left time limit
array[n_obs] real<lower=0> right_t;     // Right time limit
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
real<lower=0> prior_scale_x1; // Assume a Normal(0, prior_scale_x1) distribution for the age-specific trajectories at t = 1.

real<lower=0> prior_scale_contactmatrix;
matrix<lower = 0>[1,2] prior_dist_pi;
}

transformed data {
vector<lower = 0>[n_obs] I_D_rev;                        // Reversed discretized infection-to-death distribution

array[3] int x_i;
array[2 * n_obs + A] real x_r;
real<lower = 0> gamma;
real<lower = 0> tau;

array[A * n_difeq] real init = rep_array(0.0, A * n_difeq);    // Initial conditions for the (S,E,I,C) compartments

vector[A] ones_vector_A = rep_vector(1.0, A);

vector[L_raw_length] L_vector = rep_vector(0, L_raw_length);

//---- Infection-fatality rate per age group
for( t in 1:n_obs ) I_D_rev[t] = I_D[n_obs - t + 1];

x_i[1] = A;
x_i[2] = n_obs;
x_i[3] = n_difeq;

x_r[1:n_obs]                         = left_t;
x_r[(n_obs+1):(2 * n_obs)]           = right_t;
x_r[(2 * n_obs + 1):(2 * n_obs + A)] = age_dist;

tau    = 2.0 / incubation_period;
gamma  = 2.0 / infectious_period;

}

parameters {
real x0;                          // Initial transmission rate
array[A] real x_init;
array[(n_changes - 1)*A] real x_noise;
real<lower = 0, upper = 1> pi;    // Number of population infections at t0
array[A] real<lower = 0> volatilities;  // Standard deviation of GBM
real<lower = 0> phiD;             // Likelihood variance parameter
vector[L_raw_length] L_raw;       // Vectorized version of the L matrix. Used to apply a NCP to calculate the sampled contact matrix .
}

transformed parameters{
matrix[n_changes, A] x_trajectory;
real<lower = 0> beta0;                           // Initial transmission rate

matrix<lower = 0>[n_obs, A] beta_trajectory;     // Daily Effective contact rate, beta_trajectory = exp(x_trajectory)
array[n_obs*A] real<lower = 0> beta_N;           // Daily Effective contact rate, vectorised

array[A*A + A*n_obs + 4] real theta;             // Vector of ODE parameters
array[n_obs, A * n_difeq] real state_solutions;  // Solution from the ODE solver
matrix[n_obs, A] comp_C;			             // Store the calculated values for the dummy ODE compartment

matrix<lower = 0>[n_obs, A] E_casesByAge;        // Expected infections per group
matrix<lower = 0>[n_obs, A] E_deathsByAge;       // Expected deaths per age group

matrix[A, A] cm_sym;
matrix[A, A] cm_sample;

//---- Transformed parameters for the contact matrix (Non-central parameterisation):
matrix[A, A] L_raw_mat               = to_triangular(L_raw, A);
matrix[A, A] L                       = to_triangular(L_vector, A);
matrix[n_changes - 1, A] x_noise_mat = to_matrix(x_noise, n_changes - 1, A);

for(col in 1:A) for(row in col:A) L[row,col] = L_cm[row,col] + (prior_scale_contactmatrix * L_cm[row,col]) *  L_raw_mat[row,col];

cm_sym    = tcrossprod(L);
cm_sample = diag_pre_multiply(pop_diag, cm_sym);

//---- Transformed parameters for the GBM (Non-central parameterisation):
x_trajectory[1,] = to_row_vector(x_init);

for (t in 2:n_changes) for (j in 1:A) x_trajectory[t,j] = x_trajectory[t-1,j] + volatilities[j] * x_noise_mat[t-1,j];

beta0 = exp(x0);

if (ecr_changes == 1) {
  beta_trajectory = exp(x_trajectory);

} else {
 beta_trajectory = append_row( repeat_matrix(       exp( x_trajectory[1:(n_changes-1),] ), ecr_changes),
                               repeat_rv_to_matrix( exp( x_trajectory[n_changes      ,] ), n_remainder)
                               );
}

beta_N = to_vector_colwise(beta_trajectory);

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
		comp_C[t,j] = state_solutions[t,(n_difeq-1) * A + j] * n_pop;

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
x_init       ~ normal(0, prior_scale_x1);
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
deviance = (-2) * sum(log_lik);
}
