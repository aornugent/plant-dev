# Does TF24's hyperparameterisation overwrite a parameter set in strategy_default
# (the driver's THETA route), and does editing strategies[[1]] after add_strategies hold?
#   PLANT_LIB=... Rscript check_theta.R
source("harness/long_drought.R")
p <- scm_base_parameters("TF24")
s <- p$strategy_default; sp <- s$pars
sp$d_I <- sp$d_I * 1.1; sp$a_dG1 <- sp$a_dG1 * 1.1; sp$a_dG2 <- sp$a_dG2 * 1.1
s$pars <- sp; p$strategy_default <- s
q <- add_strategies(p, trait_matrix(LMA0, "lma"))
for (n in c("d_I", "a_dG1", "a_dG2", "TF24_cost_scale", "storage_relaxation_offset")) {
  cat(sprintf("%-26s strategy_default %.10g  after add_strategies %.10g\n", n,
              p$strategy_default$pars[[n]], q$strategies[[1]]$pars[[n]]))
}
s1 <- q$strategies[[1]]; sp1 <- s1$pars; sp1$d_I <- sp1$d_I * 2; s1$pars <- sp1; q$strategies[[1]] <- s1
cat("d_I after a direct edit of strategies[[1]]:", q$strategies[[1]]$pars$d_I, "\n")
