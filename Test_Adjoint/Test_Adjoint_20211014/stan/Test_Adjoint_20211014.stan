functions {

	vector SIR(real time,     // Time
               vector y,      // System state of the ODE [susceptible, infected, recovered] at the time specified
			   real beta0,
			   vector beta_N,
			   real gamma,
			   vector left_t,
			   vector right_t,
               int n_obs,     // Length of the time series
               int n_pop,     // Population
               int n_difeq)   // Number of differential equations
			         {

	   // NOTE: Return a vector with the solution to the system:
      vector[n_difeq] dy_dt;
      real beta;

      // Time-dependent incidence rate:
      for (i in 1:n_obs) {
        if(time >= 0 && time < 1) beta = beta0;
        else if(time >= left_t[i] && time <= right_t[i]) beta = beta_N[i];
      }// End for

      // Dummy compartment to record the cumulative incidence:
      dy_dt[4] = beta * y[1] * y[2] / n_pop;

      // S compartment:
      dy_dt[1] = - dy_dt[4];

      // R compartment:
      dy_dt[3] = gamma * y[2];

      // I compartment:
      dy_dt[2] = -(dy_dt[1] + dy_dt[3]);

      return dy_dt;
    }// End SIR function
}

data {
  int<lower = 1> n_obs;              // Number of days observed
  int<lower = 1> n_pop;              // Population
  int<lower = 1> n_difeq;            // Number of differential equations

  int y_deaths[n_obs];               // Data, total number of new deaths
  vector[n_difeq] initial_state_raw; // Initial states

  int<lower = 1> sigmaBM_cp1;        // Change-point 1
  int<lower = 1> sigmaBM_cp2;        // Change-point 2

  real ts[n_obs];                    // Time points observed

  vector<lower = 0>[n_obs] left_t;   // Left time limit
  vector<lower = 0>[n_obs] right_t;  // Right time limit

  // Priors:
  real eta0_sd;
  real eta1_sd;
  real gamma_shape;
  real gamma_scale;
  real sigmaBM_sd;
  real reciprocal_phi_scale;

  real I_D[n_obs];
  int weeks_ahead;

  // Adjoint ODE solver parameters:
  real rel_tol_forward;
  vector[n_difeq] abs_tol_forward;
  real rel_tol_backward;
  vector[n_difeq] abs_tol_backward;
  real rel_tol_quadrature;
  real abs_tol_quadrature;
  int max_num_steps;
  int num_steps_between_checkpoints;
  int interpolation_polynomial;
  int solver_forward;
  int solver_backward;
}

transformed data {
  real I_D_rev[n_obs];
  for(i in 1:n_obs) I_D_rev[i] = I_D[n_obs - i + 1];
}

parameters {
  real eta0;
  vector[n_obs] eta;

  real<lower = 0> gamma;

  real<lower = 0> sigmaBM1;
  real<lower = 0> sigmaBM2;
  real<lower = 0> sigmaBM3;

  real<lower = 0> reciprocal_phiD;
}

transformed parameters{
  real<lower = 0> beta0;
  vector<lower = 0>[n_obs] beta_N;     // transmission rate, beta = exp(eta)
  vector[n_difeq] state_estimate[n_obs];

  real<lower = 0> E_cases[n_obs];
  real<lower = 0> E_deaths[n_obs];
  real<lower = 0> phiD;
  vector[n_difeq] initial_state;

  real ifr;
  real initial_time;
  real times[n_obs];

  initial_time = 0.0;                  // Initial time point
  times = ts;
  ifr = 0.01;

  beta0 = exp(eta0);
  beta_N = exp(eta);

  // Solution to the ODE:
  for (i in 1:n_difeq) initial_state[i] = initial_state_raw[i];

  state_estimate = ode_adjoint_tol_ctl(SIR,
                                       initial_state,
                                       initial_time,
                                       times,
                                       rel_tol_forward,                       // Relative tolerance for forward solve
                                       abs_tol_forward,                       // Absolute tolerance vector for each state for forward solve
                                       rel_tol_backward,                      // Relative tolerance for backward solve
                                       abs_tol_backward,                      // Absolute tolerance vector for each state for backward solve
                                       rel_tol_quadrature,                    // Relative tolerance for backward quadrature
                                       abs_tol_quadrature,                    // Absolute tolerance for backward quadrature
									   max_num_steps,                         // Maximum number of time-steps to take in integrating the ODE solution between output time points for forward and backward solve
									   num_steps_between_checkpoints,         // Number of steps between checkpointing forward solution
                                       interpolation_polynomial,              // Interpolation polynomial: 1=Hermite, 2=polynomial
                                       solver_forward,                        // Solver for forward phase: 1=Adams, 2=BDF
                                       solver_backward,                       // Solver for backward phase: 1=Adams, 2=BDF
                                       beta0, beta_N, gamma, left_t, right_t, n_obs, n_pop, n_difeq);

  for (i in 1:n_obs) {

    // Expected new cases by calendar day:
    E_cases[i] = state_estimate[i,4] - (i==1 ? 0 : (state_estimate[i,4] > state_estimate[i-1,4] ? state_estimate[i-1,4] : 0) );

    // Expected deaths by calendar day:
    if(i == 1) E_deaths[i] = 1e-010;
    else E_deaths[i] =  ifr * dot_product(head(E_cases,i-1), tail(I_D_rev, i-1));

  }// End for

  phiD = 1. / reciprocal_phiD;
}

model {

  // Prior distributions:
  eta0 ~ normal(0, eta0_sd);
  gamma ~ gamma(gamma_shape, gamma_scale);

  sigmaBM1 ~ normal(0, sigmaBM_sd);
  sigmaBM2 ~ normal(0, sigmaBM_sd);
  sigmaBM3 ~ normal(0, sigmaBM_sd);

  reciprocal_phiD ~ cauchy(0, reciprocal_phi_scale);

  eta[1] ~ normal(0, eta1_sd);

  for (i in 2:n_obs){

   if(i < sigmaBM_cp1) eta[i] ~ normal(eta[i-1], sigmaBM1);
   else if (sigmaBM_cp1 < i < sigmaBM_cp2) eta[i] ~ normal(eta[i-1], sigmaBM2);
   else eta[i] ~ normal(eta[i-1], sigmaBM3);

  }// End for

  //for (i in 1:n_obs) y_deaths[i] ~ neg_binomial_2(E_deaths[i], phiD);
  y_deaths ~ neg_binomial_2(E_deaths, phiD);
}

generated quantities {
  vector[n_obs] R_t;                  // Time-varying reproduction number
  vector[n_obs] log_lik;              // Log-likelihood
  real dev;                           // Deviance
  int pred_daily_deaths[n_obs];       // Daily predicted deaths
  int pred_weekly_deaths[weeks_ahead];// Weekly predicted deaths

  // Time-varying reproduction number (vectorized):
   R_t = beta_N/gamma;

  // Log-likelihood:
  for (i in 1:n_obs) {
    //R_t[i] = beta_N[i]/gamma;
    log_lik[i] = neg_binomial_2_lpmf(y_deaths[i]| E_deaths[i], phiD);
  }// End for

  // Daily predicted deaths:
  pred_daily_deaths = neg_binomial_2_rng(E_deaths, 1/phiD);

  // Weekly predicted deaths:
  for(i in 1:weeks_ahead){
    int start = 1 + 7*(i-1);
    int end = min(start + 6, n_obs);
    pred_weekly_deaths[i] = sum(pred_daily_deaths[start:end]);
  }// End for

  // Deviance:
  dev = (-2) * sum(log_lik);
}