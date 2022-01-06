module Test_module

#---- Libraries
using Turing
using LazyArrays
using DifferentialEquations
using Random:seed!
seed!(1)

#---- Functions:
function NegativeBinomial2(mu, phi)
 p = 1 / (1 + mu / phi)
 r = phi

 return NegativeBinomial(r, p)
end # End function

function sir_ode!(du, u, p, t)
	
	# Design of vector p: [nobs, n_pop, gamma, beta0, beta1, ..., betaN, left_t1, ..., left_tN, right_t1,..., right_tN]
	n_obs   = p[1]
    n_pop   = p[2]
	gamma   = p[3]
    beta0   = p[4]
	beta_N  = p[5:(5 + nobs - 1)]
	left_t  = p[(5 + nobs):(5 + 2*nobs - 1)]
	right_t = p[(5 + 2*nobs):(5 + 3*nobs - 1)]

    for i in 1:n_obs 
	    #beta = ifelse(t >= 0 && t < 1, beta0, ifelse(t >= left_t[i] && t <= right_t[i], beta_N[i]) )
        if t >= 0 && t < 1 
			beta = beta0
        elseif t >= left_t[i] && t <= right_t[i]
			beta = beta_N[i]
		end
    end

    infection = beta * u[1] * u[2] / n_pop 
    recovery = gamma * u[2]
	
    @inbounds begin
	    du[4] = infection
        du[1] = -infection
		du[3] = recovery
        du[2] = du[4] - du[3]
    end
    nothing
end # End function

#---- Model:
@model bayes_sir(y_deaths, 
				 n_obs,
				 n_pop,
				 y_init,
				 ts,
				 left_t,
				 right_t,
				 eta0_sd,
				 eta1_sd,
				 gamma_shape,
				 gamma_scale,
				 sigmaBM_sd,
				 reciprocal_phi_scale,
				 sigmaBM_cp1,
				 sigmaBM_cp2,
				 I_D_rev) = begin
				 
  eta = Vector(undef, n_obs)
  
  # Initiate the vector of E_cases & E_deaths:
  E_cases  = Vector(undef, n_obs) 
  E_deaths = Vector(undef, n_obs)
  
  # Prior distributions:
  eta0 ~ TruncatedNormal(0, eta0_sd, 0, 10)        
  
  gamma ~ truncated(Gamma(gamma_shape, gamma_scale), 0, 10)

  sigmaBM1 ~ TruncatedNormal(0, sigmaBM_sd, 0, 10) 
  sigmaBM2 ~ TruncatedNormal(0, sigmaBM_sd, 0, 10) 
  sigmaBM3 ~ TruncatedNormal(0, sigmaBM_sd, 0, 10) 
  
  reciprocal_phiD ~ truncated(Cauchy(0, reciprocal_phi_scale), 0, 10)
  
  eta[1] ~ TruncatedNormal(0, eta1_sd, 0, 10) 

  for i in 2:n_obs
   if i < sigmaBM_cp1 
      eta[i] ~ TruncatedNormal(eta[i-1], sigmaBM1, 0, 10)
   elseif sigmaBM_cp1 < i < sigmaBM_cp2 
      eta[i] ~ TruncatedNormal(eta[i-1], sigmaBM2, 0, 10)
   else eta[i] ~ TruncatedNormal(eta[i-1], sigmaBM3, 0, 10)
   end # End if
  end # End for
  
  # Transformations:
  phiD = 1.0 / reciprocal_phiD

  ifr = 0.01
 
  beta0  = exp.(eta0)
  beta_N = exp.(eta)
  
  # ODE solutions:
  p = [n_obs, n_pop, gamma, beta0, beta_N, left_t, right_t]
 
  prob = ODEProblem(sir_ode!,
	                y_init,
		            ts,
		            p)
  sol = solve(prob,
			  Euler(),        # Solvers: https://diffeq.sciml.ai/stable/solvers/ode_solve/
			  saveat = 1.0)   # Obtain the solution at an even grid of 1 time units (Daily data points)
  
  # Access the solutions
  y_hat  = Array(sol)[4, :]   # Daily cumulative cases

  for i in 1:n_obs

   # Expected new cases by calendar day:
   E_cases[i] = ifelse(i == 1, y_hat[i], ifelse(y_hat[i] > y_hat[i-1], y_hat[i] - y_hat[i-1], y_hat[i]) )

   # Expected deaths by calendar day:
   E_deaths[i] = ifelse(i == 1, 1e-010, ifr * dot(front(E_cases,i-1), tail(I_D_rev, i-1)) )
   
  end # End for

  # Likelihood:
  y_deaths ~ arraydist(LazyArray(@~ NegativeBinomial2.(E_deaths, phiD)))
end # End model

end # End module Test_module