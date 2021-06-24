//
// This dummy Stan program is taken from Georges Monette's webpage
// http://blackwell.math.yorku.ca/MATH6635/files/Stan_first_examples.html
// It's inclusion in the Bernadette folder directory serves only for
// successful compilation of the package during its early development stages,
// and shall be removed at later versions.
//
// All credits go to the author.

data {
    int N;
    vector[N] weight;
    vector[N] height;
    vector[N] health;
}

parameters {
  real b_0;
  real b_weight;
  real b_height;
  real<lower=0> sigma_y;
}

model {
  health ~ normal(
    b_0 + b_weight * weight + b_height * height,
    sigma_y);   // model of form y ~ normal(mean, sd)
}

