real x0[A];                       // Initial transmission rate
real x_noise[n_obs*A];
real<lower = 0, upper = 1> pi;    // Number of population infections at t0																	  
real<lower = 0> volatilities[A];  // Standard deviation of GBM
real<lower = 0> phiD;             // Likelihood variance parameter
vector[(A * (A + 1)) / 2] L_raw;  // Vectorized version of the L matrix. Used to apply a NCP to calculate the sampled contact matrix .