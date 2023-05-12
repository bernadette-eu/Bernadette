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
matrix[x_noise, A] x_noise_mat = to_matrix(x_noise, n_obs, A);

for(col in 1:A) for(row in col:A) L[row,col] = L_cm[row,col] + (prior_scale_contactmatrix * L_cm[row,col]) *  L_raw_mat[row,col];

cm_sym    = tcrossprod(L);
cm_sample = diag_pre_multiply(pop_diag, cm_sym);						

//---- Transformed parameters for the GBM (Non-central parameterisation):                           			
for (j in 1:A) x_trajectory[1,] = x0[j] + volatilities[j] * x_noise_mat[1,j];

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
		E_casesByAge[t,j] = comp_C[t,j] - (t == 1 ? 0 :  ( comp_C[t,j] > comp_C[t-1,j] ? comp_C[t-1,j] : 0) );

		//--- Expected deaths by calendar day and age group:
		if(t != 1) E_deathsByAge[t,j] =  age_specific_ifr[t,j] * dot_product(head(E_casesByAge[,j], t-1), tail(I_D_rev, t-1));
	}// End for
}//End for
