# Causal control.  The claim is that storage entering the growth rate is what
# invalidates the transport term.  Setting the gate threshold far below zero
# makes G ~ 1 for every reserve fraction, so the pool still evolves and still
# drives mortality, but no longer enters the growth rate.  If the claim holds,
# the two coordinate systems must then agree and converge, as they do on FF16
# and K93.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1) + tail(tt,-1)) / 2)))

run_pair <- function(a_st2, label) {
  p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
  s <- p0$strategies[[1]]; s$pars$a_st2 <- a_st2; p0$strategies[[1]] <- s
  tt <- p0$node_schedule_times[[1]]
  for (lev in 0:1) {
    if (lev > 0) tt <- midpoints(tt)
    p <- p0; p$node_schedule_times <- list(tt)
    v <- sapply(c(FALSE, TRUE), function(bd) {
      ct <- Control(); ct$node_density_in_birth_date <- bd
      run_scm(p, Environment("TF24"), ct, collect=FALSE, refine_schedule=FALSE)$offspring_production
    })
    cat(sprintf("%-22s lev%d n=%-4d height=%-12.6g birth=%-12.6g  relative gap=%.3e\n",
                label, lev, length(tt), v[1], v[2], abs(v[2]-v[1])/abs(v[1])))
    flush.console()
  }
}
cat("gate threshold a_st2 = 0.1 is the shipped value; -10 puts G within 1e-43 of 1 for all r.\n\n")
run_pair(0.1,  "gate active")
run_pair(-10,  "gate removed from g")
