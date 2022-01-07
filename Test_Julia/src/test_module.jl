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

function sir_ode(u, p, t)
		
    # See https://stackoverflow.com/questions/30626713/creating-an-array-of-arrays-in-julia
	# https://diffeq.sciml.ai/stable/tutorials/ode_example/
	n_obs   = p[1]
    n_pop   = p[2]
	n_difeq = p[3]
	gamma   = p[4]
    beta0   = p[5]
	beta_N  = p[6]
	left_t  = p[7]
	right_t = p[8]
  
  	# NOTE: Initialize the vector which returns the solution to the system:
    dy_dt = Vector{Float64}(undef, n_difeq)
	
	# Time-dependent incidence rate:
	beta  = 0.1 # Assign an arbitrary floating number, instead of Vector(float64, 1) 

    # Source: 
	# https://discourse.julialang.org/t/quick-for-and-if-one-line-loop/43199
	# https://discourse.julialang.org/t/if-elseif-else-performance/24622/8
    for i in 1:n_obs 
        if t >= 0 && t < 1 
			beta = beta0
        elseif t >= left_t[i] && t <= right_t[i]
			beta = beta_N[i] #beta[1]
		end
    end

    infection = beta * u[1] * u[2] / n_pop 
    recovery = gamma * u[2]
	
	# Dummy compartment to record the cumulative incidence:
	dy_dt[n_difeq] = infection
		
    # S compartment:
    dy_dt[1] = -infection
		
    # R compartment:
	dy_dt[3] = recovery
		
	# I compartment:
	dy_dt[2] = dy_dt[n_difeq] - dy_dt[3]

     return dy_dt
end # End function

#---- Model:
@model bayes_sir(y_deaths, 
				 n_obs,
				 n_pop,
				 n_difeq,
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
  p = Any[]
  push!(p, n_obs)
  push!(p, n_pop)
  push!(p, n_difeq)
  push!(p, gamma)
  push!(p, beta0)
  push!(p, beta_N)
  push!(p, left_t)
  push!(p, right_t)
  
  prob = ODEProblem(sir_ode, y_init, ts, p)
  sol = solve(prob,
			  Midpoint(),     # Solvers: https://diffeq.sciml.ai/stable/solvers/ode_solve/
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