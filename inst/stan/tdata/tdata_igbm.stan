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
