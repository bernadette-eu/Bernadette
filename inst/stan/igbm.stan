functions {
#include /functions/functions_igbm.stan
}

data {							  
#include /data/data_igbm.stan
}

transformed data {
#include /model/tdata_igbm.stan
}

parameters {
#include /priors/parameters_igbm.stan																			
}

transformed parameters{
#include /priors/tparameters_igbm.stan
}

model {

//---- Prior distributions:
#include /priors/priors_igbm.stan

//---- Likelihood:
for(i in 1:n_obs) {
	for (j in 1:A) {
		if (likelihood_variance_type == 0)      target += neg_binomial_2_lpmf( y_data[i,j] | E_deathsByAge[i,j], phiD);
		else if (likelihood_variance_type == 1) target += neg_binomial_2_lpmf( y_data[i,j] | E_deathsByAge[i,j], E_deathsByAge[i,j]/phiD);
	}// End for
}// End for
}

generated quantities {
#include /gqs/gen_quantities_igbm.stan
}
