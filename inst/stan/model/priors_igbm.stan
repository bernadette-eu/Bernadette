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
																	