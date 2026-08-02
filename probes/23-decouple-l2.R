# Third refinement level for the decoupled control, to distinguish a converging
# quadrature residual from a second non-vanishing coupling.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1) + tail(tt,-1)) / 2)))
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s <- p0$strategies[[1]]; s$pars$a_st2 <- -10; s$pars$a_dG1 <- 0; p0$strategies[[1]] <- s
tt <- midpoints(midpoints(p0$node_schedule_times[[1]]))
p <- p0; p$node_schedule_times <- list(tt)
v <- sapply(c(FALSE, TRUE), function(bd) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  run_scm(p, Environment("TF24"), ct, collect=FALSE, refine_schedule=FALSE)$offspring_production
})
cat(sprintf("storage carried, reads nothing  lev2 n=%-4d height=%-12.6g birth=%-12.6g  relative gap=%.3e\n",
            length(tt), v[1], v[2], abs(v[2]-v[1])/abs(v[1])))
