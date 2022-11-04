functions {
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
	
	real[] ODE_states(real time,     // Time
					  real[] y,      // System state {susceptible,infected,recovered}
					  real[] theta,  // Parameters
					  real[] x_r,    // Real-type data
					  int[] x_i      // Integer-type data
					  ){
	
	  int A       = x_i[1];    // Number of age groups
	  int n_obs   = x_i[2];    // Length of the time series
	  int n_difeq = x_i[3];    // Number of differential equations in the system
	  
	  real dy_dt[A * n_difeq]; // SEIR (ignoring R) then C 
	  real f_inf[A];           // Force of infection
      real init[2 * A];        // Initial values at (S, E1) compartmens

      real age_dist[A] = x_r[(2 * n_obs + 1):(2 * n_obs + A)];  // Population per age group

      // Estimated parameters:
      real contact[A * A]  = theta[1:(A * A)];  // Sampled contact matrix in vectorized format.
	                                            // First A values correspond to number of contact between age class 1 and other classes, etc.
	  real gamma           = theta[A * A + 1];  // Recovery rate
	  real tau             = theta[A * A + 2];  // Incubation rate
      real pi              = theta[A * A + 3];  // Number of cases at t0
	  real beta            = theta[A * A + 4];  // Effective contact rate
	  
      // Compartments:
      for (i in 1:A){
        
		init[i]     = age_dist[i] * (1-pi); // Initial states - Susceptibles
        init[A + i] = age_dist[i] * pi;     // Initial states - Exposed 1
		
	    // Force of infection by age group:
		f_inf[i] = beta * sum( ( to_vector( y[(3 * A + 1):(4 * A)] ) + 
		                           to_vector( y[(4 * A + 1):(5 * A)] ) 
		                        ) ./ to_vector(age_dist) .* to_vector(contact[( A * (i-1) + 1 ):( i * A )]) 
							  ); 
        				
        // S: susceptible
        dy_dt[i] = - f_inf[i] * ( y[i] + init[i] ); 
		
		// E1: incubating (not yet infectious)
        dy_dt[A + i] = f_inf[i] * ( y[i] + init[i] ) - tau * ( y[A + i] + init[A + i] );
 
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
	
    // Integration using the trapezoidal rule:
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
      real theta_ODE[A*A + 4];

	  real left_t[n_obs]  = x_r[1:n_obs];              // Left and right time bounds for the calculation of the time-dependent incidence rate
      real right_t[n_obs] = x_r[(n_obs+1):(2 * n_obs)];// Left and right time bounds for the calculation of the time-dependent incidence rat

      // Define the parameter vector that enters the ode_states():		 
      theta_ODE[1:(A * A)] = theta[1:(A * A)];       // Vectorized contact matrix
      theta_ODE[A * A + 1] = theta[A * A + 1];       // gamma = Recovery rate
      theta_ODE[A * A + 2] = theta[A*A + n_obs + 4]; // tau   = Incubation rate
      theta_ODE[A * A + 3] = theta[A*A + n_obs + 3]; // pi
 
      for (t in 0:(size(times)-1)) {
		if(t == 0){

		   theta_ODE[A * A + 4] = theta[A * A + 2]; // beta0
		   
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
            
			// Assign the effective contact rate parameter at the last time point
            if (t == (size(times) - 1) ) theta_ODE[A * A + 4] = theta[A * A + n_obs + 2];         
            else if(t >= left_t[t] && t <= right_t[t]) theta_ODE[A * A + 4] = theta[A*A + t + 2];
					
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
  // Structure:								  
  int<lower = 1> A;                 // Number of age groups
  int<lower = 1> n_obs;             // Length of analysis period
  int<lower = 1> n_weeks;           // Number of weeks

  int<lower = 1> n_pop;             // Population
  real age_dist[A];                 // Age distribution of the general population
  vector[A] pop_diag;               // Inverse of population for each age group
  
  int<lower = 1> n_difeq;           // Number of differential equations (S,I,C)
  
  vector[A] L_cm[A];                // Lower triangular matrix, stemming from the Cholesky decomposition of the observed Contact matrix
  real<lower = 0> ifr_age[A];       // Infection-fatality rate per age group
  
  real t0;                          // Initial time point (zero)
  real ts[n_obs];                   // Time bins
  real<lower=0> left_t[n_obs];      // Left time limit
  real<lower=0> right_t[n_obs];     // Right time limit
  vector<lower = 0>[n_obs] I_D;     // Discretized infection to death distribution.          
  row_vector[A] E_deathsByAge_day1; // Age-group deaths at day 1 of the analysis
  
  // Data to fit:
  int y_deaths[n_obs,A];            // Mortality data (new daily deaths), per age group
  
  // Fixed parameters:
  real dE;
  real dI;            
 
  // Priors:
  real eta0_sd;
  real p_phiD;                      // Exponential prior on phiD
  real p_sigmaCM;                
  real p_sigmaBM[2];                // Cauchy[Location, scale] on sigma_BM
  matrix<lower = 0>[1,2] p_pi;
 
  // Debugging:
  int inference; // 0: simulating from priors; 1: fit to data
  int doprint;
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

  for(i in 1:n_obs) I_D_rev[i] = I_D[n_obs - i + 1];

  x_i[1] = A;
  x_i[2] = n_obs;
  x_i[3] = n_difeq;
   
  x_r[1:n_obs]                         = left_t;
  x_r[(n_obs+1):(2 * n_obs)]           = right_t;
  x_r[(2 * n_obs + 1):(2 * n_obs + A)] = age_dist;
  
  gamma  = 2.0/dI;
  tau    = 2.0/dE;
}

parameters {
  real eta0;                                // Initial transmission rate
  real eta_init;                            // Initial transmission rate
  real eta_noise[n_weeks - 1];

  real<lower = 0, upper = 1> pi;            // Number of cases at t0
  real<lower = p_sigmaBM[1]> sigmaBM;       // Standard deviation of GBM
  real<lower = 0> phiD;                     // Likelihood variance parameter

  vector[(A * (A + 1)) / 2] L_raw;          // Vectorized version of the L matrix. Used to apply a NCP to calculate the sampled contact matrix 
}

transformed parameters{
  
  real eta_weekly[n_weeks];                  // log(Weekly transmission rate)
  real<lower = 0> beta0;                     // Initial transmission rate

  real<lower = 0> beta_weekly[n_weeks];      // Weekly Effective contact rate, beta_weekly = exp(eta_weekly)
  real<lower = 0> beta_N[n_obs];             // Daily Effective contact rate

  real theta[n_obs + A * A + 4];             // Vector of ODE parameters
  real state_solutions[n_obs, A * n_difeq];  // Solution from the ODE solver
  matrix[n_obs, A] comp_C;			         // Store the calculated values for the dummy ODE compartment
  
  matrix<lower = 0>[n_obs, A] E_casesByAge;  // Expected infections per group
  matrix<lower = 0>[n_obs, A] E_deathsByAge; // Expected deaths per age group
  
  matrix[A, A] cm_sym;
  matrix[A, A] cm_sample;

  // Transformed parameters for the contact matrix (Non-centered parameterisation):
  matrix[A, A] L_raw_mat = to_triangular(L_raw, A);
  matrix[A, A] L         = to_triangular(L_vector, A);

  for(col in 1:A) for(row in col:A) L[row,col] = L_cm[row,col] + (p_sigmaCM * L_cm[row,col]) *  L_raw_mat[row,col];
 
  cm_sym    = tcrossprod(L);
  cm_sample = diag_pre_multiply(pop_diag, cm_sym);

  // Transformed parameters for the GBM (Non-central parameterisation):
  eta_weekly[1] = eta_init;                               
  
  for (i in 2:n_weeks) eta_weekly[i] = eta_weekly[i-1] + sigmaBM  *  eta_noise[i-1]; // Implies eta_weekly[i] ~ normal(eta_weekly[i-1], sigmaBM);
  
  beta0       = exp(eta0);
  beta_weekly = exp(eta_weekly);
  beta_N      = rep_each(beta_weekly, 7);   // Assume that, within each week, the transmission rate does not change.
  
  // Change of format for integrate_ode_euler/ integrate_ode_rk45/ integrate_ode_bdf:
  theta[1:(A * A)]                       = to_vector_rowwise(cm_sample);                      
  theta[A * A + 1]                       = gamma;                     
  theta[A * A + 2]                       = beta0;
  theta[(A * A + 3):(A * A + n_obs + 2)] = beta_N; 
  theta[n_obs + A * A + 3]               = pi; 
  theta[n_obs + A * A + 4]               = tau; 

  // Solution to the ODE system:
  state_solutions = integrate_ode_trapezoidal(init,   // initial states
											  t0,     // initial_time, 
											  ts,     // real times
											  theta,  // parameters
											  x_r,    // real data
											  x_i     // integer data
											  );
											  
  // Calculate new daily Expected cases and Expected deaths for each age group:
  for (i in 1:n_obs) {
	  
	if(i == 1) E_deathsByAge[i,] = E_deathsByAge_day1;

    for (j in 1:A){

     // Format ODE results
	 comp_C[i,j] = state_solutions[i,(n_difeq-1) * A + j]  *  n_pop;

     // Alternative option:
     E_casesByAge[i,j] = comp_C[i,j] - (i == 1 ? 0 :  ( comp_C[i,j] > comp_C[i-1,j] ? comp_C[i-1,j] : 0) );

     // Expected deaths by calendar day and age group:
	 if(i != 1) E_deathsByAge[i,j] =  ifr_age[j] * dot_product(head(E_casesByAge[,j],i-1), tail(I_D_rev, i-1));
    }// End for

  }//End for
  
  // Debug:
  if(doprint != 0) {
	  print("cm_sample: ", cm_sample);
	  print("beta0: ", beta0);
	  print("beta_N: ", beta_N);
	  print("Expected Cases: ",  E_casesByAge);
	  print("Expected Deaths: ", E_deathsByAge);
  }// End debugging
  
}

model {
	
  // Priors:
  eta0      ~ normal(0, eta0_sd);
  eta_noise ~ std_normal();
  eta_init  ~ normal(0, p_sigmaBM[2]);
  pi        ~ beta(p_pi[1,1], p_pi[1,2]);
  sigmaBM   ~ normal(0, p_sigmaBM[2]);
  phiD      ~ exponential(p_phiD);
  L_raw     ~ std_normal();

  // Likelihood:
  if (inference != 0) {
   for(i in 1:n_obs) {
	for (j in 1:A) {
      target += neg_binomial_2_lpmf( y_deaths[i,j] | E_deathsByAge[i,j], E_deathsByAge[i,j]/phiD);
    }// End for
   }// End for
  }// End if
}

generated quantities {
  vector[n_obs] E_cases;          // Expected infections <lower = 0>
  vector[n_obs] E_deaths;         // Expected deaths <lower = 0>
  matrix[n_obs, A] Susceptibles;  // Counts of susceptibles at time t, for age group a = 1,..,A.
                                  // To be used for the calculation of the time-varying Effective Reproduction Number.
  matrix[n_obs,A] log_like_age; 
  vector[n_obs] log_lik;          // Log-likelihood vector for loo package.
  real deviance;                  // Deviance

  // Total expected number of new infections per day:
  E_cases = E_casesByAge * ones_vector_A;

  // Total expected number of new deaths per day:
  E_deaths = E_deathsByAge * ones_vector_A;

  for (i in 1:n_obs) {

	for (j in 1:A) {
	 	Susceptibles[i,j] = ( state_solutions[i,j] + (age_dist[j]  * (1-pi)) )* n_pop ;
		log_like_age[i,j] = neg_binomial_2_lpmf(y_deaths[i,j] | E_deathsByAge[i,j], E_deathsByAge[i,j]/phiD);
    }// End for
	 
    log_lik[i] = sum(log_like_age[i,]);
  }// End for

  // Deviance:
  deviance = (-2)  *  sum(log_lik);
}
