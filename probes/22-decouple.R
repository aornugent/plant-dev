# A cleaner control than 21.  Opening the gate alone leaves storage driving
# mortality, so reserves drain, mortality saturates and the stand dies; the
# comparison is then made on an empty patch.  Setting a_dG1 = 0 as well removes
# storage-dependent mortality, so the pool is carried and integrated but reads
# into nothing.  The strategy is then size-structured in the sense that matters
# here, and the two coordinate systems must agree.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1) + tail(tt,-1)) / 2)))

run_pair <- function(mod, label) {
  p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
  s <- p0$strategies[[1]]; s <- mod(s); p0$strategies[[1]] <- s
  tt <- p0$node_schedule_times[[1]]
  for (lev in 0:1) {
    if (lev > 0) tt <- midpoints(tt)
    p <- p0; p$node_schedule_times <- list(tt)
    v <- sapply(c(FALSE, TRUE), function(bd) {
      ct <- Control(); ct$node_density_in_birth_date <- bd
      run_scm(p, Environment("TF24"), ct, collect=FALSE, refine_schedule=FALSE)$offspring_production
    })
    cat(sprintf("%-34s lev%d n=%-4d height=%-12.6g birth=%-12.6g  relative gap=%.3e\n",
                label, lev, length(tt), v[1], v[2], abs(v[2]-v[1])/abs(v[1])))
    flush.console()
  }
}
run_pair(function(s) { s$pars$a_st2 <- -10; s$pars$a_dG1 <- 0; s },
         "storage carried, reads nothing")
run_pair(function(s) { s$pars$a_dG1 <- 0; s },
         "gate active, no storage mortality")
