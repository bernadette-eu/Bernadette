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