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
		
		if (likelihood_variance_type == 0)      log_like_age[t,j] = neg_binomial_2_lpmf(y_deaths[t,j] | E_deathsByAge[t,j], phiD);
		else if (likelihood_variance_type == 1) log_like_age[t,j] = neg_binomial_2_lpmf(y_deaths[t,j] | E_deathsByAge[t,j], E_deathsByAge[t,j]/phiD);
		
	}// End for

	log_lik[t] = sum(log_like_age[t,]);
}// End for

//---- Deviance:
deviance = (-2)  *  sum(log_lik);

