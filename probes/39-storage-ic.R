# TF24_Strategy::set_initial_states fills a newborn's carbohydrate store to
# a_st3 * storage_capacity.  It is called from Node::compute_initial_conditions
# (the SCM path) and from nowhere else -- StochasticSpecies::introduce_new_node
# does not call it.  So IBM seedlings are born with an empty store and grow
# more slowly.  Quantify: free growth from birth with a full vs an empty store.
source("probes/lib.R"); setwd("/home/user/plant-dev")

p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]
cat("a_st3 =", s1$pars$a_st3, "  height_0 =", TF24_Individual(s1)$state("height"), "\n")

## --- (1) what each solver actually gives a newborn -----------------
ct <- Control(); ct$node_density_in_birth_date <- TRUE
scm <- scm_collect(p, "TF24", ct)
tmm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
k <- which.min(abs(tmm - 1)); spS <- scm$history[[k]]$species[[1]]
nb <- spS$new_node$individual
cat(sprintf("SCM  new_node at t=1 : height=%.6f storage=%.6e leafarea=%.6e\n",
            nb$state("height"), nb$state("storage"), nb$compute_competition(0)))

pp <- p; pp$patch_area <- 32; pp$max_patch_lifetime <- 1
ty  <- plant:::extract_RcppR6_template_types(pp, "Parameters")
obj <- do.call(plant:::StochasticPatchRunner, ty)(pp, Environment("TF24"), Control())
sc  <- plant:::NodeSchedule(1); sc$max_time <- 1; sc$set_times(seq(1/64, 1, by=1/32), 1)
obj$node_schedule <- sc
obj$run_next()          # introduces the first individual
i1 <- obj$patch$species[[1]]$individuals[[1]]
cat(sprintf("IBM  individual #1 just after introduction: t=%.5f height=%.6f storage=%.6e leafarea=%.6e\n",
            obj$patch$time, i1$state("height"), i1$state("storage"), i1$compute_competition(0)))
i0 <- TF24_Individual(s1)
cat(sprintf("bare TF24_Individual()                    : height=%.6f storage=%.6e\n",
            i0$state("height"), i0$state("storage")))

## --- (2) free growth, full vs empty store --------------------------
env <- Environment("TF24"); env$set_fixed_environment(1.0, 150)
times <- seq(0.02, 3, by = 0.02)
traj <- function(storage) {
  ind <- TF24_Individual(s1); ind$set_state("storage", storage)
  r <- grow_individual_to_time(ind, times, env)
  data.frame(t = times,
             h = vapply(r$individual, function(i) i$state("height"), 0),
             a = vapply(r$individual, function(i) i$compute_competition(0), 0),
             m = vapply(r$individual, function(i) i$state("mortality"), 0))
}
S_full <- nb$state("storage")
tf <- traj(S_full); te <- traj(0)
cat(sprintf("\nfree growth in an open canopy (storage at birth: full=%.4e, empty=0)\n", S_full))
cat(sprintf("%6s %11s %11s %7s | %10s %10s %7s\n","age","a_full","a_empty","ratio","h_full","h_empty","ratio"))
for (tt in c(0.1,0.25,0.5,0.75,1,1.5,2,2.5,3)) {
  i <- which.min(abs(times-tt))
  cat(sprintf("%6.2f %11.4e %11.4e %7.4f | %10.5f %10.5f %7.4f\n",
      times[i], tf$a[i], te$a[i], tf$a[i]/te$a[i], tf$h[i], te$h[i], tf$h[i]/te$h[i]))
}

## --- (3) implied population ratio ----------------------------------
# leaf area per m2 at patch age T with lambda=1 is int_0^T S(u) a(u) du
cum <- function(d) { y <- exp(-d$m)*d$a; c(0, cumsum((head(y,-1)+tail(y,-1))/2 * diff(d$t))) }
Cf <- approxfun(c(0,tf$t), cum(tf)); Ce <- approxfun(c(0,te$t), cum(te))
ex <- readRDS("probes/out/excess-scm.rds"); AG <- c(1,1.5,2,2.5,3)
scm561 <- ex$scm[["561"]][match(AG, ex$ages)]
lad <- c(0.003360, 0.021329, 0.083451, 0.232201, 0.508246)  # regular-arrival IBM, A=128
cat(sprintf("\n%6s %12s %12s %8s | %12s %12s %8s\n","age","int a_full","int a_empty","ratio",
            "SCM(561)","IBM ladder","ratio"))
for (i in seq_along(AG))
  cat(sprintf("%6.1f %12.6f %12.6f %8.4f | %12.6f %12.6f %8.4f\n",
      AG[i], Cf(AG[i]), Ce(AG[i]), Cf(AG[i])/Ce(AG[i]), scm561[i], lad[i], scm561[i]/lad[i]))
cat("\n(the open-canopy integral overshoots at later ages because competition is ignored;\n",
    " the ratio is the quantity to compare)\n")
